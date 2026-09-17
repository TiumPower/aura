module Customer
  # Khách tự đặt lịch trên PWA. Luồng đi theo từng bước và render ở SERVER
  # (không phụ thuộc JS): chọn dịch vụ → chọn ngày & giờ → xác nhận. Mỗi bước
  # chỉ là một query param, nên khách bấm back của điện thoại vẫn đúng chỗ.
  class BookingsController < BaseController
    before_action :require_workspace!
    before_action :require_member!
    before_action :require_booking_module!

    STEPS = %w[service time confirm].freeze

    def new
      @branches = current_workspace.branches.bookable.ordered.to_a
      @branch = current_workspace.branches.find_by(id: params[:branch_id]) ||
                current_member.home_branch || @branches.first
      return render(:unavailable) if @branch.nil?

      @blocked = current_member.booking_blocked?
      return if @blocked

      @categories = current_workspace.service_categories.active.ordered.to_a
      @services = current_workspace.services.bookable.ordered.to_a
      @service  = @services.find { |s| s.id.to_s == params[:service_id].to_s }
      @variant  = @service&.service_variants&.find_by(id: params[:service_variant_id])
      @addons   = current_workspace.services.addons.where(online_bookable: true).ordered.to_a

      @step = if @service.nil? then "service"
              elsif params[:time].blank? then "time"
              else "confirm"
              end

      if @service
        @staff = bookable_staff
        @chosen_staff = @staff.find { |s| s.id.to_s == params[:staff_member_id].to_s }
        @gender = params[:gender].presence
        @date = parse_date(params[:date]) || Date.current
        @finder = build_finder
        @open_days = @finder.open_days(from: Date.current, days: @branch.setting_i("booking_horizon_days").clamp(1, 21))
        @date = @open_days.first if @open_days.any? && !@open_days.include?(@date)
        @slots = @date ? @finder.slots_on(@date) : []
        @chosen_slot = @slots.find { |s| s.starts_at.strftime("%H:%M") == params[:time] } if params[:time].present?
        @step = "time" if params[:time].present? && @chosen_slot.nil?
        @chosen_addons = current_workspace.services.where(id: Array(params[:addon_ids])).to_a
        @estimate = estimate_total
      end
    end

    def create
      @branch  = current_workspace.branches.find(params[:branch_id])
      service  = current_workspace.services.bookable.find(params[:service_id])
      variant  = service.service_variants.find_by(id: params[:service_variant_id])
      staff    = bookable_staff.find { |s| s.id.to_s == params[:staff_member_id].to_s }
      addons   = current_workspace.services.addons.where(id: Array(params[:addon_ids])).to_a
      starts_at = parse_time(params[:date], params[:time])

      if current_member.booking_blocked?
        return redirect_to member_new_booking_path, alert: "Tài khoản của bạn đang tạm không đặt lịch online được. Vui lòng gọi trực tiếp cho spa."
      end
      return redirect_to(member_new_booking_path, alert: "Giờ hẹn không hợp lệ.") if starts_at.nil?

      result = BookingScheduler.create(
        branch: @branch, starts_at: starts_at, member: current_member,
        lines: [{ service: service, variant: variant, staff: staff, addons: addons }],
        source: "app", actor: current_member, note: params[:note].presence,
        gender: params[:gender].presence
      )

      if result.ok?
        b = result.booking
        notify_desk(b)
        redirect_to member_booking_path(id: b.id),
                    notice: b.pending? ? "Đã gửi yêu cầu — spa sẽ xác nhận trong ít phút."
                                       : "Đã đặt lịch #{b.starts_at.strftime('%H:%M %d/%m')} 🌿"
      else
        redirect_to member_new_booking_path(service_id: service.id, date: params[:date]),
                    alert: "#{result.error} Vui lòng chọn giờ khác."
      end
    end

    def index
      scope = current_member.bookings.includes(:branch, booking_items: [:service, :staff_member])
      @upcoming = scope.where(status: Booking::LIVE_STATUSES)
                       .where("bookings.starts_at >= ?", Time.current.beginning_of_day)
                       .order(:starts_at).to_a
      @past = scope.where("bookings.starts_at < ? OR bookings.status IN (?)",
                          Time.current.beginning_of_day, %w[cancelled no_show completed])
                   .order(starts_at: :desc).limit(30).to_a
    end

    def show
      @booking = current_member.bookings.includes(booking_items: [:service, :staff_member, :room])
                               .find(params[:id])
      @items = @booking.booking_items.ordered.to_a
    end

    def cancel
      @booking = current_member.bookings.find(params[:id])
      unless @booking.member_can_cancel?
        return redirect_to member_booking_path(id: @booking.id),
          alert: "Sát giờ hẹn quá nên không tự huỷ được — vui lòng gọi cho spa để đổi lịch."
      end
      @booking.transition_to!("cancelled", actor: current_member, reason: params[:reason].presence)
      notify_desk(@booking, cancelled: true)
      redirect_to member_booking_list_path, notice: "Đã huỷ lịch hẹn."
    end

    private

    def require_booking_module!
      return if current_workspace.feature?("booking")
      redirect_to member_root_path, alert: "Spa này chưa mở đặt lịch trong app."
    end

    def bookable_staff
      return [] unless @service&.requires_staff?
      return [] unless @branch.setting?("allow_staff_choice")
      rows = current_workspace.staff_members.bookable.at_branch(@branch.id).ordered.to_a
      if (capable = @service.capable_staff_ids)
        rows = rows.select { |s| capable.include?(s.id) }
      end
      rows
    end

    def build_finder
      SlotFinder.new(branch: @branch, service: @service, variant: @variant,
                     staff: @chosen_staff, gender: @gender)
    end

    # Trả về [dòng chi tiết, tổng]. Khách nhìn được từng dòng thì mới tin con số
    # cuối — và lễ tân không phải giải thích qua điện thoại.
    def estimate_total
      lines = []
      base = @service.price_for(@variant, branch: @branch)
      lines << [@variant ? "#{@service.name} #{@variant.name}" : @service.name, base]

      # Chỉ cộng phụ thu khi khách TỰ chọn KTV đó (khớp với BookingScheduler).
      surcharge = @chosen_staff&.surcharge.to_i
      if surcharge.positive?
        lines << ["Phụ thu #{@chosen_staff.display_name}", surcharge]
      end

      Array(@chosen_addons).each do |a|
        lines << [a.name, a.price_for(nil, branch: @branch)]
      end

      subtotal = lines.sum { |(_, amount)| amount }
      discount = current_member.tier_discount
      if discount.positive?
        off = (subtotal * discount / 100.0).round(-3)
        lines << ["Ưu đãi hạng #{current_member.tier_name} −#{discount}%", -off]
        subtotal -= off
      end
      @estimate_lines = lines
      subtotal
    end

    # Báo cho quầy có lịch mới / lịch bị huỷ. Quầy không ngồi nhìn màn hình cả
    # ngày, nên push là cách duy nhất họ biết kịp.
    def notify_desk(booking, cancelled: false)
      user_ids = current_workspace.users.pluck(:id)
      return if user_ids.empty?
      title = cancelled ? "Khách huỷ lịch" : "Lịch hẹn mới từ app"
      body  = "#{booking.customer_name} · #{booking.starts_at.strftime('%H:%M %d/%m')} · #{booking.service_summary}"
      PushSender.deliver_to_users(user_ids, title: title, body: body.truncate(90),
                                  path: "/merchant/bookings/#{booking.id}")
    rescue => e
      Rails.logger.error("[Booking] notify desk failed: #{e.class} #{e.message}")
    end

    def parse_date(str)
      return nil if str.blank?
      Date.parse(str.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_time(date_str, time_str)
      date = parse_date(date_str) || Date.current
      return nil if time_str.blank?
      h, m = time_str.to_s.split(":").map(&:to_i)
      return nil if h.nil?
      Time.zone.local(date.year, date.month, date.day, h, m || 0)
    end
  end
end

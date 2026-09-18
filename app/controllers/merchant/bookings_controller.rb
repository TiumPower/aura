module Merchant
  # Lịch hẹn ở quầy: xem lịch một ngày theo PHÒNG, nhận khách mới, check-in,
  # bắt đầu / kết thúc, huỷ, đánh no-show, đổi giờ.
  class BookingsController < BaseController
    before_action :set_booking, only: [:show, :edit, :update, :destroy, :status, :reschedule, :assign]

    # ---- Lịch ngày ---------------------------------------------------------
    def index
      @date   = parse_date(params[:date]) || Date.current
      @branch = current_branch || current_workspace.branches.active.ordered.first
      return redirect_to merchant_branches_path, alert: "Hãy tạo một cơ sở trước khi xếp lịch." if @branch.nil?

      @rooms = @branch.rooms.active.ordered.to_a
      @windows = @branch.open_windows(@date)
      @bookings = current_workspace.bookings.where(branch_id: @branch.id).on_date(@date)
                                  .includes(:member, booking_items: [:service, :staff_member, :room])
                                  .order(:starts_at).to_a
      @items = @bookings.flat_map(&:booking_items).reject(&:cancelled?)
      @by_room = @items.group_by(&:room_id)

      # Khung giờ hiển thị: bám giờ mở cửa, nhưng nới ra nếu có lịch nằm ngoài
      # (khách hẹn sớm/muộn hơn giờ mở cửa do quầy xếp tay).
      opens  = @windows.map(&:first).min || @date.to_time.change(hour: 9)
      closes = @windows.map(&:last).max  || @date.to_time.change(hour: 21)
      @from  = floor_hour([opens, @items.map(&:starts_at).min].compact.min)
      @to    = ceil_hour([closes, @items.map(&:ends_at).max].compact.max)

      @stats = day_stats(@items)
      @unassigned = @bookings.select(&:unassigned_staff?)
      @pending = @bookings.select(&:pending?)
      @branches = current_workspace.branches.active.ordered.to_a
    end

    # Hàng chờ ở quầy: ai đang làm, ai vừa tới, ai sắp tới.
    def queue
      @branch = current_branch || current_workspace.branches.active.ordered.first
      scope = current_workspace.bookings.where(branch_id: @branch&.id).on_date(Date.current)
                               .includes(:member, booking_items: [:service, :staff_member, :room])
      @arriving  = scope.where(status: %w[pending confirmed]).order(:starts_at).to_a
      @in_house  = scope.where(status: %w[checked_in in_progress]).order(:starts_at).to_a
      @done      = scope.where(status: "completed").order(completed_at: :desc).limit(20).to_a
      @late      = @arriving.select(&:late?)
    end

    def show
      @items = @booking.booking_items.ordered.to_a
      # Bấm vào một khối trên lịch ngày mở POPUP, không rời trang: Turbo nạp
      # đúng action này vào frame "booking_peek" và ta trả về bản xem nhanh.
      # Cùng một URL phục vụ cả hai, nên link vẫn mở được ở tab mới như thường.
      if turbo_frame_request_id == "booking_peek"
        return render partial: "merchant/bookings/peek",
                      locals: { booking: @booking, items: @items }, layout: false
      end
      @staff = current_workspace.staff_members.active.therapists.at_branch(@booking.branch_id).ordered.to_a
      @rooms = @booking.branch.rooms.active.ordered.to_a
    end

    # ---- Nhận khách mới ----------------------------------------------------
    def new
      @branch = current_branch || current_workspace.branches.active.ordered.first
      return redirect_to merchant_branches_path, alert: "Hãy tạo một cơ sở trước khi xếp lịch." if @branch.nil?
      @date = parse_date(params[:date]) || Date.current
      @walk_in = params[:walk_in] == "1"
      load_form
    end

    def create
      @branch = current_workspace.branches.find(params[:branch_id])
      service = current_workspace.services.find(params[:service_id])
      variant = service.service_variants.find_by(id: params[:service_variant_id])
      staff   = current_workspace.staff_members.find_by(id: params[:staff_member_id])
      room    = @branch.rooms.find_by(id: params[:room_id])
      addons  = current_workspace.services.where(id: Array(params[:addon_ids])).to_a
      member  = resolve_member

      starts_at = if params[:walk_in] == "1"
        Time.current
      else
        parse_time(params[:date], params[:time])
      end
      return reject("Giờ hẹn không hợp lệ.") if starts_at.nil?

      party = [params[:party_size].to_i, 1].max
      lines = (1..party).map do |i|
        { service: service, variant: variant, guest_label: "Khách #{i}",
          staff: (i == 1 ? staff : nil), room: (i == 1 ? room : nil),
          addons: (i == 1 ? addons : []) }
      end

      result = BookingScheduler.create(
        branch: @branch, starts_at: starts_at, lines: lines, member: member,
        guest_name: params[:guest_name].presence, guest_phone: params[:guest_phone].presence,
        source: params[:walk_in] == "1" ? "walk_in" : "staff",
        actor: current_user, note: params[:note].presence,
        internal_note: params[:internal_note].presence,
        party_size: party, gender: params[:gender].presence,
        hold_token: params[:hold_token].presence
      )

      if result.ok?
        audit!("booking.create", target: result.booking,
               summary: "#{result.booking.code} · #{result.booking.customer_name} · #{starts_at.strftime('%H:%M %d/%m')}")
        redirect_to merchant_booking_path(result.booking), notice: "Đã tạo lịch hẹn #{result.booking.code}."
      else
        reject(result.error)
      end
    end

    # ---- Trạng thái --------------------------------------------------------
    def status
      target = params[:value].to_s
      unless @booking.can_transition_to?(target)
        return redirect_back fallback_location: merchant_booking_path(@booking),
                             alert: "Không chuyển được từ “#{@booking.status_label}” sang trạng thái đó."
      end
      @booking.transition_to!(target, actor: current_user, reason: params[:reason].presence)
      audit!("booking.#{target}", target: @booking, summary: @booking.code)
      redirect_back fallback_location: merchant_booking_path(@booking),
                    notice: "#{@booking.code}: #{@booking.status_label}."
    end

    # Gán KTV / phòng cho một lượt (lễ tân xếp tay).
    def assign
      item = @booking.booking_items.find(params[:item_id])
      staff = current_workspace.staff_members.find_by(id: params[:staff_member_id])
      room  = @booking.branch.rooms.find_by(id: params[:room_id])
      finder = SlotFinder.new(branch: @booking.branch, service: item.service,
                              variant: item.service_variant, exclude_booking: @booking,
                              ignore_lead_time: true)
      if staff && !finder.staff_free?(staff, item.starts_at, item.ends_at)
        return redirect_to merchant_booking_path(@booking), alert: "#{staff.display_name} không rảnh giờ này."
      end
      if room && !finder.room_free?(room, item.starts_at, item.ends_at, item.buffer_minutes)
        return redirect_to merchant_booking_path(@booking), alert: "#{room.display_name} đã có khách giờ này."
      end
      item.update!(staff_member: staff || item.staff_member, room: room || item.room,
                   staff_surcharge: (staff || item.staff_member)&.surcharge.to_i)
      @booking.recalculate_total!
      audit!("booking.assign", target: @booking, summary: "#{item.service_label} → #{staff&.display_name || '—'}")
      redirect_to merchant_booking_path(@booking), notice: "Đã gán KTV/phòng."
    end

    def reschedule
      starts_at = parse_time(params[:date], params[:time])
      return redirect_to(merchant_booking_path(@booking), alert: "Giờ mới không hợp lệ.") if starts_at.nil?
      result = BookingScheduler.reschedule(booking: @booking, starts_at: starts_at, actor: current_user)
      if result.ok?
        audit!("booking.reschedule", target: @booking, summary: starts_at.strftime("%H:%M %d/%m"))
        redirect_to merchant_booking_path(@booking), notice: "Đã đổi giờ hẹn."
      else
        redirect_to merchant_booking_path(@booking), alert: result.error
      end
    end

    def edit
      @items = @booking.booking_items.ordered.to_a
    end

    def update
      if @booking.update(booking_params)
        redirect_to merchant_booking_path(@booking), notice: "Đã lưu lịch hẹn."
      else
        @items = @booking.booking_items.ordered.to_a
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      code = @booking.code
      @booking.destroy
      audit!("booking.destroy", summary: code)
      redirect_to merchant_calendar_path, notice: "Đã xoá lịch hẹn #{code}."
    end

    # ---- Giờ còn trống (JSON cho form đặt lịch) ----------------------------
    def slots
      branch  = current_workspace.branches.find(params[:branch_id])
      service = current_workspace.services.find(params[:service_id])
      variant = service.service_variants.find_by(id: params[:service_variant_id])
      staff   = current_workspace.staff_members.find_by(id: params[:staff_member_id])
      date    = parse_date(params[:date]) || Date.current
      finder = SlotFinder.new(branch: branch, service: service, variant: variant, staff: staff,
                              gender: params[:gender].presence,
                              party_size: params[:party_size].presence || 1,
                              ignore_lead_time: true)
      slots = finder.slots_on(date)
      render json: {
        date: date.to_s,
        slots: slots.map { |s|
          { time: s.starts_at.strftime("%H:%M"), room_id: s.room&.id,
            room: s.room&.display_name, staff_id: s.staff&.id, staff: s.staff&.display_name }
        }
      }
    end

    private

    def set_booking
      @booking = current_workspace.bookings.includes(booking_items: [:service, :staff_member, :room])
                                  .find(params[:id])
    end

    def load_form
      @services = current_workspace.services.main.active.ordered.to_a
      @addons   = current_workspace.services.addons.ordered.to_a
      @staff    = current_workspace.staff_members.active.therapists.at_branch(@branch.id).ordered.to_a
      @rooms    = @branch.rooms.active.ordered.to_a
      @branches = current_workspace.branches.active.ordered.to_a
      @recent_members = current_workspace.members.active.order(last_visit_at: :desc).limit(30).to_a
    end

    def resolve_member
      if params[:member_id].present?
        current_workspace.members.find_by(id: params[:member_id])
      elsif params[:guest_phone].present?
        # Quầy nhập SĐT: nếu số đó đã có hồ sơ thì dùng lại, không tạo hồ sơ thứ hai.
        phone = Member.canonical_phone(params[:guest_phone])
        current_workspace.members.find_by(phone: phone) ||
          current_workspace.members.create!(phone: phone, name: params[:guest_name].to_s,
                                            source: "walk_in", home_branch_id: @branch.id)
      end
    end

    def reject(message)
      flash.now[:alert] = message
      @date = parse_date(params[:date]) || Date.current
      @walk_in = params[:walk_in] == "1"
      load_form
      render :new, status: :unprocessable_entity
    end

    def booking_params
      params.require(:booking).permit(:note, :internal_note, :party_size, :guest_name, :guest_phone)
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

    # Khung giờ của lịch phải trùm hết mọi lượt, làm tròn ra giờ chẵn để cột
    # giờ không cắt ngang một lượt khách.
    def floor_hour(time) = time.change(min: 0, sec: 0)

    def ceil_hour(time)
      (time.min.zero? && time.sec.zero?) ? time : time.change(min: 0, sec: 0) + 1.hour
    end

    def day_stats(items)
      seat_hours = @rooms.sum(&:capacity) * @windows.sum { |(f, t)| (t - f) / 3600.0 }
      sold_hours = items.sum { |i| i.duration_minutes / 60.0 }
      revenue = @bookings.reject { |b| %w[cancelled no_show].include?(b.status) }.sum(&:estimated_total)
      {
        bookings: @bookings.count { |b| b.live? },
        guests: @bookings.select(&:live?).sum(&:party_size),
        sold_hours: sold_hours.round(1),
        seat_hours: seat_hours.round(1),
        utilization: seat_hours.positive? ? (sold_hours * 100.0 / seat_hours).round : 0,
        revenue: revenue,
        revpath: sold_hours.positive? ? (revenue / sold_hours).round : 0,
        no_shows: @bookings.count(&:no_show?),
        cancelled: @bookings.count(&:cancelled?)
      }
    end

    def nav_key = :calendar
  end
end

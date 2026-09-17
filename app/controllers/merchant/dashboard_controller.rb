module Merchant
  # MỘT trang cho chủ spa. Nguyên tắc bố cục: **một khái niệm là MỘT khối, hai
  # mốc thời gian (hôm nay / theo kỳ) nằm TRONG cùng khối đó.**
  #
  # Bản gộp đầu tiên làm sai chính chỗ này: nó dán hai dashboard cạnh nhau, nên
  # "tỷ lệ dùng KTV" có hai thẻ rời (26% hôm nay ở trên, 28% theo kỳ ở dưới) và
  # người đọc phải tự nối hai số lại. Tiền cũng bị xé thành ba thẻ không liên hệ
  # (doanh thu / chi phí / lãi) thay vì đọc như một chuỗi P&L.
  #
  # Thứ tự khối theo việc chủ spa thật sự làm khi mở trang:
  #   1. việc phải xử lý ngay (chỉ hiện khi có việc)
  #   2. nhịp hôm nay — tiến độ ngày, đã thu so với một ngày thứ N bình thường
  #   3. tiền theo kỳ — chuỗi doanh thu → chi phí → hoa hồng → lãi thô
  #   4. khai thác — dùng KTV (kèm vùng chuẩn ngành), lấp chỗ, RevPATH
  #   5. khách — quay lại/mới/bỏ hẹn/đặt online + danh sách nên gọi
  #   6. xếp hạng dịch vụ và KTV
  class DashboardController < BaseController
    PERIODS = { "7" => "7 ngày", "30" => "30 ngày", "90" => "90 ngày" }.freeze

    def show
      return redirect_to merchant_onboarding_path if current_workspace && !current_workspace.onboarded?

      ws = current_workspace
      @branches = ws.branches.where.not(status: "archived").ordered.to_a
      @branch   = current_branch
      load_today(ws)
      load_period(ws)
      @setup_todos = setup_todos
    end

    private

    # ---- TẦNG 1: hôm nay ---------------------------------------------------
    def load_today(ws)
      today = Date.current
      bookings = by_branch(ws.bookings).on_date(today)
                                       .includes(:member, booking_items: [:service, :staff_member, :room])
                                       .order(:starts_at).to_a
      @today_bookings = bookings.reject { |b| %w[cancelled no_show].include?(b.status) }
      @today_guests   = @today_bookings.sum(&:party_size)
      @pending        = bookings.select(&:pending?)
      @in_house       = bookings.select { |b| %w[checked_in in_progress].include?(b.status) }
      @next_up        = @today_bookings.select { |b| b.starts_at >= Time.current && %w[pending confirmed].include?(b.status) }.first(5)
      @late           = bookings.select { |b| %w[pending confirmed].include?(b.status) && b.late? }
      @unassigned     = @today_bookings.select(&:unassigned_staff?)
      @today_no_shows = bookings.count(&:no_show?)
      # Tiến độ ngày: ba con số này cộng lại bằng tổng lịch hẹn hôm nay, nên vẽ
      # được thành một thanh liền — dễ đọc hơn bốn thẻ số rời.
      @today_done     = @today_bookings.count { |b| b.status == "completed" }
      @today_ahead    = @today_bookings.count { |b| %w[pending confirmed].include?(b.status) }

      orders = by_branch(ws.orders)
      paid_today = orders.paid.closed_between(today.beginning_of_day, today.end_of_day)
      @revenue_today = paid_today.sum(:total)
      @bills_today   = paid_today.count
      @atv_today     = @bills_today.positive? ? (@revenue_today / @bills_today) : 0
      @open_orders   = orders.open.includes(:member).recent.to_a
      # So với TRUNG BÌNH 4 ngày cùng thứ gần nhất, không phải với đúng ngày này
      # tuần trước. Một mẫu duy nhất cho ra những con số như "-55%" chỉ vì tuần
      # trước tình cờ có một ngày đông — đó là nhiễu, không phải tín hiệu.
      same_weekdays = (1..4).map { |n| today - 7 * n }
      sums = same_weekdays.map do |d|
        orders.paid.closed_between(d.beginning_of_day, d.end_of_day).sum(:total)
      end.reject(&:zero?)
      @baseline_days = sums.size
      @revenue_baseline = sums.any? ? (sums.sum / sums.size) : 0
      @weekday_name = I18n.l(today, format: "%A").downcase

      rooms = by_branch(ws.rooms)
      @rooms_count       = rooms.count
      @rooms_active      = rooms.active.count
      @seat_capacity     = rooms.active.sum(:capacity)
      @rooms_maintenance = rooms.where(status: "maintenance").count
      @therapist_count   = ws.staff_members.active.at_branch(@branch&.id).therapists.count

      @today_open_hours = open_hours(today, today)
      @today_capacity_hours = capacity_hours(today, today)
      sold = BookingItem.where(booking_id: @today_bookings.map(&:id)).live.sum(:duration_minutes)
      @today_sold_hours = (sold / 60.0).round(1)
      @utilization_today = @today_capacity_hours.positive? ?
        (@today_sold_hours * 100.0 / @today_capacity_hours).round : 0

      shifts = ws.staff_shifts.working.on_date(today)
      shifts = shifts.where(branch_id: @branch.id) if @branch
      shifts = shifts.to_a
      @on_duty_now = shifts.count { |s| s.starts_at <= Time.current && s.ends_at >= Time.current }
      # Giờ KTV có mặt hôm nay — MẪU SỐ chuẩn ngành cho "tỷ lệ dùng KTV"
      # (therapist utilization, trung bình ngành 50–60%, tốt là >75%).
      @today_staff_hours = shifts.sum(&:hours).round(1)
      @today_staff_utilization = @today_staff_hours.positive? ?
        (@today_sold_hours * 100.0 / @today_staff_hours).round : 0

      if ws.feature?("packages")
        @cards_low = ws.member_packages.usable.includes(:member, :package_credits).select(&:low_on_sessions?).first(6)
        @cards_expiring = ws.member_packages
                            .expiring_within(ws.setting_i("package_expiry_warning_days"))
                            .includes(:member).limit(6).to_a
      else
        @cards_low = []
        @cards_expiring = []
      end
      @birthday_members = ws.members.birthday_in(today.month).order(:dob_day).limit(6).to_a
    end

    # ---- TẦNG 2: theo kỳ ---------------------------------------------------
    def load_period(ws)
      @from, @to = period_range
      @period_days = params[:days].presence || "30"
      range = @from.beginning_of_day..@to.end_of_day

      orders = by_branch(ws.orders).paid.closed_between(range.first, range.last)
      @revenue   = orders.sum(:total)
      @bills     = orders.count
      @atv       = @bills.positive? ? (@revenue / @bills) : 0
      @tips      = orders.sum(:tip_total)
      @discounts = orders.sum(:discount_total)

      items = OrderItem.joins(:order).where(orders: { id: orders.select(:id) })
      @by_kind = items.group(:kind).sum("order_items.total")
      @service_revenue = @by_kind.values_at("service", "addon").compact.sum
      @package_revenue = @by_kind.values_at("package", "topup").compact.sum
      @retail_revenue  = @by_kind["product"].to_i
      @retail_ratio = @service_revenue.positive? ? (@retail_revenue * 100.0 / @service_revenue).round(1) : 0

      done = by_branch(ws.bookings).where(status: "completed", starts_at: range)
      @completed = done.count
      minutes = BookingItem.where(booking_id: done.select(:id)).live.sum(:duration_minutes)
      @treated_hours = (minutes / 60.0).round(1)
      # RevPATH chỉ tính doanh thu DỊCH VỤ — tiền bán thẻ là thu trước cho các
      # buổi sau, cộng vào sẽ làm tháng bán được thẻ trông như tháng vận hành giỏi.
      @revpath = @treated_hours.positive? ? (@service_revenue / @treated_hours).round : 0
      @seat_hours = capacity_hours(@from, @to)
      @room_utilization = @seat_hours.positive? ? (@treated_hours * 100.0 / @seat_hours).round(1) : 0

      # Tỷ lệ dùng KTV: giờ đã bán / giờ KTV có mặt. Đây là chỉ số ngành spa dùng
      # để quản lý (50–60% là trung bình, >75% là tốt) — nó nói "người mình thuê
      # có được dùng không". Tỷ lệ lấp PHÒNG tính trên toàn bộ giờ mở cửa × mọi
      # chỗ luôn ra vài phần trăm với spa nhiều ghế, nên không dùng làm chỉ số
      # chính được; giữ lại như số phụ để biết còn dư địa mở thêm ca.
      staff_shifts = ws.staff_shifts.working.between(@from, @to)
      staff_shifts = staff_shifts.where(branch_id: @branch.id) if @branch
      @staff_hours = staff_shifts.to_a.sum(&:hours).round(1)
      @staff_utilization = @staff_hours.positive? ?
        (@treated_hours * 100.0 / @staff_hours).round(1) : 0

      all_bk = by_branch(ws.bookings).where(starts_at: range)
      slots = all_bk.count
      @no_shows  = all_bk.where(status: "no_show").count
      @cancelled = all_bk.where(status: "cancelled").count
      @no_show_rate = slots.positive? ? (@no_shows * 100.0 / slots).round(1) : 0
      @online_share = slots.positive? ?
        (all_bk.where(source: %w[app web]).count * 100.0 / slots).round : 0

      member_ids = orders.where.not(member_id: nil).distinct.pluck(:member_id)
      @guests = member_ids.size
      @returning = Member.where(id: member_ids).where("visits_count > 1").count
      @return_rate = @guests.positive? ? (@returning * 100.0 / @guests).round : 0
      @new_members = ws.members.where(created_at: range).count
      @members_count = ws.members.count

      @top_services = items.where(kind: %w[service addon]).group(:name)
                           .order(Arel.sql("SUM(order_items.total) DESC")).limit(8)
                           .sum("order_items.total")
      @top_staff = items.where.not(staff_member_id: nil).group(:staff_member_id)
                        .order(Arel.sql("SUM(order_items.total) DESC")).limit(8)
                        .sum("order_items.total")
      @staff_index = ws.staff_members.where(id: @top_staff.keys).index_by(&:id)

      @expenses    = by_branch(ws.expenses).in_range(@from, @to).sum(:amount)
      @commissions = ws.commission_entries.in_range(@from, @to).sum(:amount)
      @profit = @revenue - @expenses - @commissions
    end

    # Tổng giờ mở cửa của các cơ sở trong khoảng (để hiện cho người đọc).
    def open_hours(from, to)
      branch_scope_list.sum { |b| branch_open_hours(b, from, to) }.round(1)
    end

    # GIỜ-CHỖ: mẫu số của tỷ lệ lấp chỗ. PHẢI nhân theo TỪNG cơ sở rồi mới cộng.
    # Lấy (tổng giờ mở cửa mọi cơ sở) × (tổng số chỗ mọi cơ sở) là nhân chỗ của
    # cơ sở A với giờ của cơ sở B — mẫu số phồng lên đúng bằng số cơ sở và tỷ lệ
    # lấp chỗ bị chia nhỏ tương ứng.
    def capacity_hours(from, to)
      branch_scope_list.sum do |b|
        seats = b.rooms.active.sum(:capacity)
        next 0.0 if seats.zero?
        branch_open_hours(b, from, to) * seats
      end.round(1)
    end

    def branch_open_hours(branch, from, to)
      (from..to).sum { |d| branch.open_windows(d).sum { |(f, t)| (t - f) / 3600.0 } }
    end

    def branch_scope_list = @branch ? [@branch] : @branches

    def period_range
      if params[:from].present? && params[:to].present?
        begin
          return [Date.parse(params[:from]), Date.parse(params[:to])].minmax
        rescue ArgumentError
          nil
        end
      end
      days = params[:days].presence&.to_i
      days = 30 unless [7, 30, 90].include?(days)
      [Date.current - (days - 1), Date.current]
    end

    def setup_todos
      ws = current_workspace
      todos = []
      todos << { text: "Thêm phòng / giường cho cơ sở", path: merchant_branches_path } if ws.rooms.empty?
      todos << { text: "Thêm kỹ thuật viên", path: merchant_staff_index_path } if ws.staff_members.active.therapists.empty?
      todos << { text: "Khai dịch vụ để bán và đặt lịch", path: merchant_services_path } if ws.services.main.active.empty?
      todos << { text: "Khai mẫu ca làm để xếp lịch tự động", path: merchant_shifts_path } if ws.shift_templates.empty?
      todos << { text: "Nhập tài khoản nhận tiền (VietQR)", path: merchant_payment_settings_path } unless ws.bank_configured?
      todos
    end

    def nav_key = :dashboard
  end
end

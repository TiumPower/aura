module Merchant
  # Tổng quan. Màn hình chủ spa mở mỗi sáng, nên nó phải trả lời đúng bốn câu
  # theo thứ tự: hôm nay có bao nhiêu khách, đã thu bao nhiêu, có gì cần xử lý
  # ngay, và sức chứa còn dư không.
  class DashboardController < BaseController
    def show
      return redirect_to merchant_onboarding_path if current_workspace && !current_workspace.onboarded?

      ws = current_workspace
      @branches = ws.branches.where.not(status: "archived").ordered.to_a
      @branch   = current_branch
      today = Date.current

      # ---- Hôm nay: lịch hẹn ----
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

      # ---- Hôm nay: tiền ----
      orders = by_branch(ws.orders)
      paid_today = orders.paid.closed_between(today.beginning_of_day, today.end_of_day)
      @revenue_today = paid_today.sum(:total)
      @bills_today   = paid_today.count
      @atv_today     = @bills_today.positive? ? (@revenue_today / @bills_today) : 0
      @open_orders   = orders.open.includes(:member).recent.to_a
      # So với cùng kỳ tuần trước để con số hôm nay có ngữ cảnh.
      last_week = today - 7
      @revenue_last_week = orders.paid
                                 .closed_between(last_week.beginning_of_day, last_week.end_of_day)
                                 .sum(:total)

      # ---- Sức chứa hôm nay ----
      rooms = by_branch(ws.rooms)
      @rooms_count       = rooms.count
      @rooms_active      = rooms.active.count
      @seat_capacity     = rooms.active.sum(:capacity)
      @rooms_maintenance = rooms.where(status: "maintenance").count

      staff = ws.staff_members.active.at_branch(@branch&.id)
      @therapist_count = staff.therapists.count
      @today_open_hours = open_hours_today
      @today_capacity_hours = (@today_open_hours * @seat_capacity).round(1)
      sold_minutes = BookingItem.where(booking_id: @today_bookings.map(&:id)).live.sum(:duration_minutes)
      @today_sold_hours = (sold_minutes / 60.0).round(1)
      @utilization = @today_capacity_hours.positive? ?
        (@today_sold_hours * 100.0 / @today_capacity_hours).round : 0

      shifts = ws.staff_shifts.working.on_date(today)
      shifts = shifts.where(branch_id: @branch.id) if @branch
      @on_duty_now = shifts.select { |s| s.starts_at <= Time.current && s.ends_at >= Time.current }.size

      # ---- Khách & thẻ cần chăm ----
      @members_count = ws.members.count
      @new_members_month = ws.members.where("created_at >= ?", today.beginning_of_month).count
      @birthday_members = ws.members.birthday_in(today.month).order(:dob_day).limit(6).to_a
      if ws.feature?("packages")
        @cards_low = ws.member_packages.usable.includes(:member, :package_credits).select(&:low_on_sessions?).first(6)
        @cards_expiring = ws.member_packages
                            .expiring_within(ws.setting_i("package_expiry_warning_days"))
                            .includes(:member).limit(6).to_a
      else
        @cards_low = []
        @cards_expiring = []
      end

      @setup_todos = setup_todos
    end

    private

    def open_hours_today
      list = (@branch ? [@branch] : @branches)
      list.sum do |b|
        b.open_windows(Date.current).sum { |(from, to)| (to - from) / 3600.0 }
      end.round(1)
    end

    # Việc còn thiếu để spa chạy được thật — hiện thẳng trên tổng quan thay vì
    # để chủ spa tự phát hiện lúc khách đã tới.
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

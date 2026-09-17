module Merchant
  # Tổng quan vận hành. Ở P0 màn này cho biết SỨC CHỨA và ĐỘI NGŨ — hai thứ
  # quyết định mọi con số doanh thu sau này. Các chỉ số lịch hẹn / doanh thu
  # được nối vào khi module đặt lịch và thu ngân lên.
  class DashboardController < BaseController
    def show
      return redirect_to merchant_onboarding_path if current_workspace && !current_workspace.onboarded?

      ws = current_workspace
      @branches = ws.branches.where.not(status: "archived").ordered.to_a
      @branch   = current_branch

      rooms = by_branch(ws.rooms)
      @rooms_count    = rooms.count
      @rooms_active    = rooms.active.count
      @seat_capacity   = rooms.active.sum(:capacity)
      @rooms_maintenance = rooms.where(status: "maintenance").count

      staff = ws.staff_members.active.at_branch(@branch&.id)
      @staff_count      = staff.count
      @therapist_count  = staff.therapists.count
      @bookable_count   = staff.bookable.count

      # Sức chứa lý thuyết hôm nay = tổng giờ mở cửa × số chỗ. Đây là mẫu số của
      # mọi chỉ số hiệu suất (RevPATH, tỷ lệ lấp phòng) ở các phase sau.
      @today_open_hours = open_hours_today
      @today_capacity_hours = (@today_open_hours * @seat_capacity).round(1)

      # Giờ KTV thực có mặt hôm nay — so với sức chứa để thấy đang thiếu người
      # hay thiếu phòng.
      shifts = ws.staff_shifts.working.on_date(Date.current)
      shifts = shifts.where(branch_id: @branch.id) if @branch
      @today_staff_hours = shifts.to_a.sum(&:hours).round(1)
      @on_duty_now = shifts.select { |s| s.starts_at <= Time.current && s.ends_at >= Time.current }.size

      @members_count = ws.members.count
      @new_members_month = ws.members.where("created_at >= ?", Date.current.beginning_of_month).count
      @app_members = ws.members.with_app.count
      @birthday_members = ws.members.birthday_in(Date.current.month).order(:dob_day).limit(8).to_a

      @expense_month = by_branch(ws.expenses).in_range(Date.current.beginning_of_month, Date.current.end_of_month).sum(:amount)

      @setup_todos = setup_todos
      @recent_audits = ws.audit_logs.recent.limit(8).to_a
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
      todos << { text: "Khai mẫu ca làm để xếp lịch tự động", path: merchant_shifts_path } if ws.shift_templates.empty?
      todos << { text: "Đặt hạng thẻ thành viên", path: merchant_member_tiers_path } if ws.member_tiers.empty?
      todos << { text: "Nhập tài khoản nhận tiền (VietQR)", path: merchant_payment_settings_path } unless ws.bank_configured?
      todos
    end

    def nav_key = :dashboard
  end
end

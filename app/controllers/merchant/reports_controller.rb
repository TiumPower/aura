module Merchant
  # Báo cáo vận hành. Chỉ số bám đúng cách ngành spa đo hiệu quả: tỷ lệ lấp chỗ,
  # doanh thu mỗi giờ trị liệu (RevPATH), bill trung bình (ATV), tỷ lệ khách
  # quay lại — chứ không chỉ "tổng doanh thu".
  class ReportsController < BaseController
    before_action :require_manager!

    def index
      @from, @to = period_range
      range = @from.beginning_of_day..@to.end_of_day
      branch_id = current_branch&.id

      orders = current_workspace.orders.paid.at_branch(branch_id).closed_between(range.first, range.last)
      @revenue  = orders.sum(:total)
      @bills    = orders.count
      @atv      = @bills.positive? ? (@revenue / @bills) : 0
      @tips     = orders.sum(:tip_total)
      @discounts = orders.sum(:discount_total)

      items = OrderItem.joins(:order).where(orders: { id: orders.select(:id) })
      @by_kind = items.group(:kind).sum("order_items.total")
      @service_revenue = @by_kind.values_at("service", "addon").compact.sum
      @package_revenue = @by_kind.values_at("package", "topup").compact.sum
      @retail_revenue  = @by_kind["product"].to_i
      @retail_ratio = @service_revenue.positive? ? (@retail_revenue * 100.0 / @service_revenue).round(1) : 0

      # Giờ trị liệu đã bán và sức chứa → tỷ lệ lấp chỗ + RevPATH.
      bookings = current_workspace.bookings.at_branch(branch_id)
                                  .where(status: "completed", starts_at: range)
      @completed = bookings.count
      treated_minutes = BookingItem.where(booking_id: bookings.select(:id)).live.sum(:duration_minutes)
      @treated_hours = (treated_minutes / 60.0).round(1)
      # RevPATH = doanh thu DỊCH VỤ trên mỗi giờ trị liệu. Tiền bán thẻ và nạp ví
      # là tiền thu TRƯỚC cho các buổi sau, cộng vào đây sẽ thổi phồng chỉ số và
      # tháng nào bán được thẻ sẽ trông như tháng vận hành xuất sắc.
      @revpath = @treated_hours.positive? ? (@service_revenue / @treated_hours).round : 0
      @seat_hours = capacity_hours(branch_id)
      @utilization = @seat_hours.positive? ? (@treated_hours * 100.0 / @seat_hours).round(1) : 0

      all_bookings = current_workspace.bookings.at_branch(branch_id).where(starts_at: range)
      @no_shows  = all_bookings.where(status: "no_show").count
      @cancelled = all_bookings.where(status: "cancelled").count
      total_slots = all_bookings.count
      @no_show_rate = total_slots.positive? ? (@no_shows * 100.0 / total_slots).round(1) : 0
      @online_share = total_slots.positive? ?
        (all_bookings.where(source: %w[app web]).count * 100.0 / total_slots).round : 0

      # Khách mới vs khách quay lại — chỉ số sống còn của một spa.
      member_ids = orders.where.not(member_id: nil).distinct.pluck(:member_id)
      @guests = member_ids.size
      @returning = Member.where(id: member_ids).where("visits_count > 1").count
      @return_rate = @guests.positive? ? (@returning * 100.0 / @guests).round : 0
      @new_members = current_workspace.members.where(created_at: range).count

      # Xếp hạng
      # `total` tồn tại ở cả order_items và orders → phải nói rõ bảng, nếu không
      # Postgres từ chối câu truy vấn.
      @top_services = items.where(kind: %w[service addon]).group(:name)
                           .order(Arel.sql("SUM(order_items.total) DESC")).limit(10)
                           .sum("order_items.total")
      @top_staff = items.where.not(staff_member_id: nil).group(:staff_member_id)
                        .order(Arel.sql("SUM(order_items.total) DESC")).limit(10)
                        .sum("order_items.total")
      @staff_index = current_workspace.staff_members.where(id: @top_staff.keys).index_by(&:id)

      @expenses = by_branch(current_workspace.expenses).in_range(@from, @to).sum(:amount)
      @commissions = current_workspace.commission_entries.in_range(@from, @to).sum(:amount)
      @profit = @revenue - @expenses - @commissions

      @branches = current_workspace.branches.ordered.to_a
    end

    private

    # Sức chứa lý thuyết của kỳ: tổng (giờ mở cửa × số chỗ) từng ngày. Đây là
    # mẫu số của tỷ lệ lấp chỗ — không có nó thì "doanh thu tăng" không cho biết
    # spa đang hiệu quả hơn hay chỉ đang mở cửa nhiều hơn.
    def capacity_hours(branch_id)
      branches = branch_id ? current_workspace.branches.where(id: branch_id) : current_workspace.branches.active
      total = 0.0
      branches.each do |b|
        seats = b.rooms.active.sum(:capacity)
        next if seats.zero?
        (@from..@to).each do |date|
          hours = b.open_windows(date).sum { |(f, t)| (t - f) / 3600.0 }
          total += hours * seats
        end
      end
      total.round(1)
    end

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

    def nav_key = :reports
  end
end

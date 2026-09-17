module Merchant
  # Bảng hoa hồng theo kỳ. Số liệu sinh ra lúc đóng bill nên đây chỉ là phép
  # cộng — không ai tính tay, không có chỗ tranh luận.
  class CommissionsController < BaseController
    before_action :require_manager!

    def index
      @from, @to = period_range
      entries = current_workspace.commission_entries.includes(:staff_member, order_item: :service)
                                 .in_range(@from, @to)
      @entries = entries.recent.limit(500).to_a
      @by_staff = entries.group(:staff_member_id).sum(:amount)
      @tips_by_staff = entries.where(basis: "tip").group(:staff_member_id).sum(:amount)
      @count_by_staff = entries.where.not(basis: "tip").group(:staff_member_id).count
      @staff = current_workspace.staff_members.where(id: @by_staff.keys).index_by(&:id)
      @total = @by_staff.values.sum
      @status_totals = entries.group(:status).sum(:amount)

      # Giờ làm trong kỳ để tính "doanh thu mỗi giờ KTV" — chỉ số cho biết
      # KTV nào đang tạo ra giá trị, không chỉ ai làm nhiều buổi.
      shifts = current_workspace.staff_shifts.working.between(@from, @to)
      @hours_by_staff = shifts.group(:staff_member_id).sum(
        Arel.sql("EXTRACT(EPOCH FROM (ends_at - starts_at)) / 3600")
      )
      @revenue_by_staff = OrderItem.joins(:order)
                                   .where(orders: { workspace_id: current_workspace.id, status: "paid" })
                                   .where(orders: { closed_at: @from.beginning_of_day..@to.end_of_day })
                                   .where.not(staff_member_id: nil)
                                   .group(:staff_member_id).sum(:unit_price)
    end

    def approve
      from, to = period_range
      n = current_workspace.commission_entries.in_range(from, to).where(status: "pending")
                           .update_all(status: "approved")
      audit!("commission.approve", summary: "#{from}–#{to}: #{n} dòng")
      redirect_to merchant_commissions_path(month: from.strftime("%Y-%m")),
                  notice: "Đã chốt #{n} dòng hoa hồng của kỳ #{from.strftime('%m/%Y')}."
    end

    private

    def period_range
      month = begin
        params[:month].present? ? Date.strptime(params[:month], "%Y-%m") : Date.current
      rescue ArgumentError
        Date.current
      end
      [month.beginning_of_month, month.end_of_month]
    end

    def nav_key = :commissions
  end
end

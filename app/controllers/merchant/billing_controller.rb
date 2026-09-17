module Merchant
  class BillingController < BaseController
    def show
      @workspace = current_workspace
      @plan = current_workspace.plan_record
      @plans = Plan.ordered.to_a
      @invoices = current_workspace.invoices.recent.limit(12).to_a
      @next_start, @next_end = current_workspace.next_billing_period
      @payos_ready = PayosService.new.configured?
      # Mức dùng so với trần của gói — con số duy nhất cho biết spa đang cần gói nào.
      @branches_count = Branch.count
      @staff_count    = StaffMember.where(status: "active").count
      @rooms_count    = Room.count
      @members_count  = Member.count
      # Nhân viên thấy nút thanh toán rồi mới bị chặn ở SubscriptionController
      # thì quá muộn — ẩn ngay từ đây.
      @can_pay = current_membership&.can_manage?
    end

    private

    def nav_key = :billing
  end
end

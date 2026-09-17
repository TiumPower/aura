module Merchant
  # Nhật ký thao tác. Sửa giá, tặng buổi, huỷ bill, đổi hoa hồng — spa nào cũng
  # có lúc cần biết ai đã làm gì.
  class AuditLogsController < BaseController
    before_action :require_manager!

    def index
      scope = current_workspace.audit_logs
      scope = scope.where("action LIKE ?", "#{params[:area]}%") if params[:area].present?
      @logs = scope.recent.limit(300).to_a
      @areas = current_workspace.audit_logs.distinct.pluck(:action).map { |a| a.split(".").first }.uniq.sort
    end

    private

    def nav_key = :audit
  end
end

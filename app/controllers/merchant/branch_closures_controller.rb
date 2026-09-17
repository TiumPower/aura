module Merchant
  # Ngày nghỉ / khoảng đóng cửa của một cơ sở (lễ, Tết, bảo trì).
  class BranchClosuresController < BaseController
    before_action :require_manager!
    before_action :set_branch

    def create
      closure = @branch.branch_closures.new(closure_params.merge(workspace: current_workspace))
      if closure.save
        audit!("branch.closure", target: @branch, summary: closure.label)
        redirect_to merchant_branch_path(@branch), notice: "Đã thêm ngày nghỉ."
      else
        redirect_to merchant_branch_path(@branch), alert: closure.errors.full_messages.to_sentence
      end
    end

    def destroy
      @branch.branch_closures.find(params[:id]).destroy
      redirect_to merchant_branch_path(@branch), notice: "Đã xoá ngày nghỉ."
    end

    private

    def set_branch = @branch = current_workspace.branches.friendly.find(params[:branch_id])

    def closure_params
      params.require(:branch_closure).permit(:starts_on, :ends_on, :starts_at, :ends_at, :reason)
    end

    def nav_key = :branches
  end
end

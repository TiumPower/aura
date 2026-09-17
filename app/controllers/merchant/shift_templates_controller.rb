module Merchant
  # Mẫu ca lặp theo tuần của một KTV.
  class ShiftTemplatesController < BaseController
    before_action :require_manager!

    def create
      staff = current_workspace.staff_members.find(params[:staff_id])
      tpl = staff.shift_templates.new(template_params.merge(workspace: current_workspace))
      tpl.branch_id ||= staff.branch_id
      if tpl.save
        redirect_to merchant_staff_path(staff), notice: "Đã thêm mẫu ca #{tpl.weekday_label}."
      else
        redirect_to merchant_staff_path(staff), alert: tpl.errors.full_messages.to_sentence
      end
    end

    def destroy
      staff = current_workspace.staff_members.find(params[:staff_id])
      staff.shift_templates.find(params[:id]).destroy
      redirect_to merchant_staff_path(staff), notice: "Đã xoá mẫu ca."
    end

    private

    def template_params
      params.require(:shift_template).permit(:weekday, :starts_at, :ends_at, :branch_id)
    end

    def nav_key = :staff
  end
end

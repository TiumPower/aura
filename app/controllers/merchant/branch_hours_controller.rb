module Merchant
  # Giờ mở cửa theo thứ của một cơ sở. Lưu hàng loạt cả 7 ngày trong một lần —
  # sửa từng dòng một là kiểu nhập liệu không ai chịu làm.
  class BranchHoursController < BaseController
    before_action :require_manager!
    before_action :set_branch

    def index = redirect_to merchant_branch_path(@branch)

    def create
      hour = @branch.branch_hours.new(hour_params.merge(workspace: current_workspace))
      if hour.save
        redirect_to merchant_branch_path(@branch), notice: "Đã thêm khung giờ."
      else
        redirect_to merchant_branch_path(@branch), alert: hour.errors.full_messages.to_sentence
      end
    end

    # Ghi lại toàn bộ bảng giờ: xoá hết rồi tạo lại từ dữ liệu form. Dòng để
    # trống cả hai giờ và không tick "Nghỉ" thì bỏ qua.
    def bulk_update
      rows = params.fetch(:hours, {}).to_unsafe_h
      ActiveRecord::Base.transaction do
        @branch.branch_hours.destroy_all
        rows.each do |weekday, entries|
          entries.each_value do |attrs|
            closed = ActiveModel::Type::Boolean.new.cast(attrs["closed"])
            opens, closes = attrs["opens_at"].presence, attrs["closes_at"].presence
            next if !closed && (opens.blank? || closes.blank?)
            @branch.branch_hours.create!(workspace: current_workspace, weekday: weekday.to_i,
                                         opens_at: opens, closes_at: closes, closed: closed)
          end
        end
      end
      audit!("branch.hours", target: @branch, summary: @branch.name)
      redirect_to merchant_branch_path(@branch), notice: "Đã lưu giờ mở cửa."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to merchant_branch_path(@branch), alert: "Không lưu được: #{e.record.errors.full_messages.to_sentence}"
    end

    private

    def set_branch = @branch = current_workspace.branches.friendly.find(params[:branch_id])

    def hour_params
      params.require(:branch_hour).permit(:weekday, :opens_at, :closes_at, :closed)
    end

    def nav_key = :branches
  end
end

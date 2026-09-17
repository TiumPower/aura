module Merchant
  # Hạng KTV + phụ thu theo hạng (khách chọn KTV hạng cao thì trả thêm).
  class StaffLevelsController < BaseController
    before_action :require_manager!
    before_action :set_level, only: [:edit, :update, :destroy]

    def index
      @levels = current_workspace.staff_levels.ordered.to_a
      @counts = current_workspace.staff_members.active.group(:staff_level_id).count
      @level  = current_workspace.staff_levels.new
      @presets = StaffLevel::PRESETS.reject { |p| current_workspace.staff_levels.exists?(key: p[:key]) }
    end

    def new = redirect_to merchant_staff_levels_path

    def create
      @level = current_workspace.staff_levels.new(level_params)
      if @level.save
        redirect_to merchant_staff_levels_path, notice: "Đã thêm hạng KTV."
      else
        @levels = current_workspace.staff_levels.ordered.to_a
        @counts = {}
        @presets = []
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @level.update(level_params)
        redirect_to merchant_staff_levels_path, notice: "Đã lưu hạng KTV."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @level.destroy
      redirect_to merchant_staff_levels_path, notice: "Đã xoá hạng KTV."
    end

    def seed_presets
      added = 0
      StaffLevel::PRESETS.each do |attrs|
        next if current_workspace.staff_levels.exists?(key: attrs[:key])
        current_workspace.staff_levels.create!(attrs)
        added += 1
      end
      redirect_to merchant_staff_levels_path, notice: "Đã nạp #{added} hạng KTV gợi ý."
    end

    private

    def set_level = @level = current_workspace.staff_levels.find(params[:id])

    def level_params
      params.require(:staff_level).permit(:key, :name, :surcharge, :commission_percent, :color, :position)
    end

    def nav_key = :staff
  end
end

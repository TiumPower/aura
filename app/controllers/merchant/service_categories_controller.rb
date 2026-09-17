module Merchant
  class ServiceCategoriesController < BaseController
    before_action :require_manager!
    before_action :set_category, only: [:edit, :update, :destroy]

    def index
      @categories = current_workspace.service_categories.ordered.to_a
      @counts = current_workspace.services.group(:service_category_id).count
      @category = current_workspace.service_categories.new
      @presets = ServiceCategory.presets_for(current_workspace.business_type)
                                .reject { |p| current_workspace.service_categories.exists?(name: p[:name]) }
    end

    def new = redirect_to merchant_service_categories_path

    def create
      @category = current_workspace.service_categories.new(category_params)
      if @category.save
        redirect_to merchant_service_categories_path, notice: "Đã thêm nhóm dịch vụ."
      else
        @categories = current_workspace.service_categories.ordered.to_a
        @counts = {}
        @presets = []
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @category.update(category_params)
        redirect_to merchant_service_categories_path, notice: "Đã lưu nhóm dịch vụ."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy
      redirect_to merchant_service_categories_path,
                  notice: "Đã xoá nhóm. Các dịch vụ trong nhóm vẫn còn, chỉ là chưa phân nhóm."
    end

    def seed_presets
      added = 0
      ServiceCategory.presets_for(current_workspace.business_type).each_with_index do |attrs, i|
        next if current_workspace.service_categories.exists?(name: attrs[:name])
        current_workspace.service_categories.create!(attrs.merge(position: i))
        added += 1
      end
      redirect_to merchant_service_categories_path, notice: "Đã nạp #{added} nhóm dịch vụ gợi ý."
    end

    private

    def set_category = @category = current_workspace.service_categories.find(params[:id])

    def category_params
      params.require(:service_category).permit(:name, :icon, :color, :position, :active)
    end

    def nav_key = :services
  end
end

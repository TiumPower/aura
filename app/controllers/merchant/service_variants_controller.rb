module Merchant
  # Biến thể thời lượng/giá: "60′ / 90′ / 120′" của cùng một dịch vụ.
  class ServiceVariantsController < BaseController
    before_action :require_manager!
    before_action :set_service

    def create
      variant = @service.service_variants.new(variant_params.merge(workspace: current_workspace))
      if variant.save
        redirect_to merchant_service_path(@service), notice: "Đã thêm biến thể #{variant.name}."
      else
        redirect_to merchant_service_path(@service), alert: variant.errors.full_messages.to_sentence
      end
    end

    def destroy
      variant = @service.service_variants.find(params[:id])
      if BookingItem.exists?(service_variant_id: variant.id)
        return redirect_to merchant_service_path(@service),
          alert: "Biến thể này đã có lịch hẹn — hãy tắt thay vì xoá."
      end
      variant.destroy
      redirect_to merchant_service_path(@service), notice: "Đã xoá biến thể."
    end

    private

    def set_service = @service = current_workspace.services.friendly.find(params[:service_id])

    def variant_params
      params.require(:service_variant).permit(:name, :duration_minutes, :price, :position, :active)
    end

    def nav_key = :services
  end
end

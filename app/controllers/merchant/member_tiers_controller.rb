module Merchant
  # Hạng thẻ thành viên: ngưỡng chi tiêu → % giảm giá + hệ số điểm.
  class MemberTiersController < BaseController
    before_action :require_manager!
    before_action :set_tier, only: [:edit, :update, :destroy]

    def index
      @tiers  = current_workspace.member_tiers.ordered.to_a
      @counts = current_workspace.members.group(:member_tier_id).count
      @tier   = current_workspace.member_tiers.new
      @presets = MemberTier::PRESETS.reject { |p| current_workspace.member_tiers.exists?(key: p[:key]) }
    end

    def new = redirect_to merchant_member_tiers_path

    def create
      @tier = current_workspace.member_tiers.new(tier_params)
      if @tier.save
        redirect_to merchant_member_tiers_path, notice: "Đã thêm hạng thẻ."
      else
        @tiers = current_workspace.member_tiers.ordered.to_a
        @counts = {}
        @presets = []
        render :index, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @tier.update(tier_params)
        redirect_to merchant_member_tiers_path, notice: "Đã lưu hạng thẻ."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tier.destroy
      redirect_to merchant_member_tiers_path, notice: "Đã xoá hạng thẻ."
    end

    def seed_presets
      added = 0
      MemberTier::PRESETS.each do |attrs|
        next if current_workspace.member_tiers.exists?(key: attrs[:key])
        current_workspace.member_tiers.create!(attrs)
        added += 1
      end
      redirect_to merchant_member_tiers_path, notice: "Đã nạp #{added} hạng thẻ gợi ý."
    end

    private

    def set_tier = @tier = current_workspace.member_tiers.find(params[:id])

    def tier_params
      params.require(:member_tier).permit(:key, :name, :min_spent, :min_visits, :discount_percent,
                                          :points_multiplier, :color, :auto_assign, :position)
    end

    def nav_key = :customers
  end
end

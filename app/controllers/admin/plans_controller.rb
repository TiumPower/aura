module Admin
  class PlansController < BaseController
    def index
      Plan.seed_defaults! if Plan.count.zero?
      @plans = Plan.ordered.to_a
    end

    def update
      @plan = Plan.find(params[:id])
      if @plan.update(plan_params)
        redirect_to admin_plans_path, notice: "Đã cập nhật gói #{@plan.name}."
      else
        @plans = Plan.ordered.to_a
        render :index, status: :unprocessable_entity
      end
    end

    private

    def nav_key = :plans

    def plan_params
      p = params.require(:plan).permit(:name, :price, :max_branches, :max_staff, :max_rooms,
                                       :allow_custom_domain, :allow_multi_branch,
                                       :allow_packages, :allow_commissions,
                                       :allow_inventory, :allow_ai, :features_text)
      # để trống = không giới hạn (nil)
      p[:max_branches] = p[:max_branches].presence
      p[:max_staff]    = p[:max_staff].presence
      p[:max_rooms]    = p[:max_rooms].presence
      features = p.delete(:features_text).to_s.split("\n").map(&:strip).reject(&:blank?)
      p.to_h.merge(features: features)
    end
  end
end

module Merchant
  # Web Push subscriptions for the landlord's own device (merchant PWA).
  class PushController < BaseController
    skip_before_action :verify_authenticity_token, only: [:subscribe, :unsubscribe], raise: false

    def subscribe
      sub = params.permit(:endpoint, keys: [:p256dh, :auth])
      endpoint = sub[:endpoint]
      keys = sub[:keys] || {}
      if endpoint.blank? || keys[:p256dh].blank? || keys[:auth].blank?
        return render json: { ok: false }, status: :unprocessable_entity
      end
      PushSubscription.store_for_user!(user: current_user, workspace: current_workspace,
                                       endpoint: endpoint, p256dh: keys[:p256dh], auth: keys[:auth])
      render json: { ok: true }
    end

    def unsubscribe
      PushSubscription.where(user_id: current_user.id, endpoint: params[:endpoint]).destroy_all if params[:endpoint].present?
      render json: { ok: true }
    end

    private

    def nav_key = :account
  end
end

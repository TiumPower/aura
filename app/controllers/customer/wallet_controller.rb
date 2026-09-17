module Customer
  # "Thẻ của tôi": thẻ liệu trình còn mấy buổi, ví trả trước, điểm thưởng và
  # lịch sử chi tiêu. Khách tự tra được là spa bớt hẳn một loại cuộc gọi.
  class WalletController < BaseController
    before_action :require_workspace!
    before_action :require_member!

    def show
      @member = current_member
      @cards = @member.member_packages.recent.includes(package_credits: :service).to_a
      @usable = @cards.select(&:usable?)
      @wallet_history = @member.wallet_transactions.recent.limit(20).to_a
      @point_history = @member.point_transactions.recent.limit(20).to_a
      @tier = @member.member_tier
      @tiers = current_workspace.member_tiers.ordered.to_a
      @next_tier = @tiers.find { |t| t.min_spent > @member.total_spent }
      @point_value = current_workspace.setting_i("points_value")
    end

    def orders
      @orders = current_member.orders.where(status: "paid")
                              .includes(:order_items, :branch).order(closed_at: :desc).limit(40).to_a
      @total = @orders.sum(&:total)
    end
  end
end

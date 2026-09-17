module Customer
  class HomeController < BaseController
    def show
      if current_workspace.nil?
        # Host gốc (không xác định được spa) → trang giới thiệu nền tảng.
        @plans = Plan.ordered.to_a
        @plans = Plan::DEFAULTS.map { |d| Plan.new(d) } if @plans.empty?
        render "customer/home/landing", layout: "marketing"
      elsif !member_signed_in? || current_member&.workspace_id != current_workspace.id
        redirect_to member_login_path
      else
        @member   = current_member
        @unread   = @member.notifications.unread.count
        @branches = current_workspace.branches.bookable.ordered.to_a
        @branch   = @member.home_branch || @branches.first
        @tier     = @member.member_tier
        @tiers    = current_workspace.member_tiers.ordered.to_a
        @next_tier = @tiers.find { |t| t.min_spent > @member.total_spent }
        @preferred_staff = @member.preferred_staff
        render :show
      end
    end
  end
end

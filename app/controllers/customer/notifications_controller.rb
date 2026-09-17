module Customer
  class NotificationsController < BaseController
    before_action :require_workspace!
    before_action :require_member!

    def index
      @notifications = current_member.notifications.recent.limit(50).to_a
      # Opening the inbox marks everything as read.
      current_member.notifications.unread.update_all(read_at: Time.current)
    end

    def read_all
      current_member.notifications.unread.update_all(read_at: Time.current)
      redirect_to member_notifications_path
    end
  end
end

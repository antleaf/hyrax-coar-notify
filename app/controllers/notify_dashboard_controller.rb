class NotifyDashboardController < ApplicationController
  with_themed_layout 'dashboard'
  def index
    @notifications = CoarNotifyInbox::Notification
                       .order(created_at: :desc)
                       .limit(1000)
  end

  def manage_connections
    @notify_inboxes = NotifyInbox.order(created_at: :desc)

    # Replace with actual model later
    @notify_services = []
  end
end
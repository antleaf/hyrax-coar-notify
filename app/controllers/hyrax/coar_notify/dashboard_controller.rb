# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class DashboardController < ApplicationController
      before_action :authorize_manager!

      def index
        @notifications = NotifyRequest.with_notifications
                           .order(updated_at: :desc)
                           .limit(1000)
      end

      def manage_connections
        @notify_inboxes = NotifyInbox.order(created_at: :desc)
        @notify_services = NotifyService.order(created_at: :desc)
      end
    end
  end
end

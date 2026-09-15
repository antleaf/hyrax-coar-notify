# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class DashboardController < ApplicationController
      before_action :authorize_admin!

      def index
        @notifications = NotifyRequest.with_notifications
                           .order(updated_at: :desc)
                           .limit(1000)
      end

      def manage_connections
        @notify_inboxes = NotifyInbox.order(created_at: :desc)
        @notify_services = NotifyService.order(created_at: :desc)
      end

      private

      def authorize_admin!
        if respond_to?(:authorize!)
          begin
            authorize! :access, :coar_notify
          rescue CanCan::AccessDenied, StandardError
            authorize! :read, :admin_dashboard rescue nil
          end
        elsif respond_to?(:authenticate_user!)
          authenticate_user!
        end
      end
    end
  end
end

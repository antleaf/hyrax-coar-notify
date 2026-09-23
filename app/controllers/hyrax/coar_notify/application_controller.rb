# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class ApplicationController < ::ApplicationController
      helper Hyrax::Engine.helpers if defined?(Hyrax::Engine)
      with_themed_layout 'dashboard' if respond_to?(:with_themed_layout)

      # Every page of this engine requires a signed-in user.
      before_action :authenticate_user!

      rescue_from CanCan::AccessDenied, with: :deny_access

      private

      # Guards the Notify dashboard and the connection (service/inbox) pages.
      # Allowed: an admin, anyone holding Hyrax::CoarNotify.config.manager_role, or anyone the
      # host's Ability grants `can :access, :coar_notify`.
      def authorize_manager!
        return if notify_manager?

        raise CanCan::AccessDenied.new(
          I18n.t('coar_notify.messages.not_authorized', default: 'You are not authorized to manage Notify connections.'),
          :access,
          :coar_notify
        )
      end

      def notify_manager?
        return false unless current_user

        admin_user? || manager_role_member? || can?(:access, :coar_notify)
      end

      # Hyrax::Ability#admin? is the canonical Hyrax admin test; User#admin? comes from hydra-role-management.
      def admin_user?
        (current_ability.respond_to?(:admin?) && current_ability.admin?) ||
          (current_user.respond_to?(:admin?) && current_user.admin?)
      end

      def manager_role_member?
        role = Hyrax::CoarNotify.config.manager_role
        role.present? && current_user.respond_to?(:groups) && Array(current_user.groups).map(&:to_s).include?(role.to_s)
      end

      # Same behaviour as Hydra::Controller's handler, so it doesn't depend on the host defining one.
      def deny_access(exception)
        if current_user
          redirect_to main_app.root_url, alert: exception.message
        else
          session['user_return_to'] = request.url
          redirect_to main_app.new_user_session_url, alert: exception.message
        end
      end
    end
  end
end

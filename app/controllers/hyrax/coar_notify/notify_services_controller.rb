# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyServicesController < ApplicationController
      before_action :authorize_admin!, except: [:request_endorsement, :request_review]
      before_action :set_notify_service, only: [:edit, :update, :destroy, :request_endorsement, :request_review]
      before_action :check_duplicate_request, only: [:request_endorsement, :request_review]

      def index
        redirect_to manage_notify_connections_path
      end

      def new
        @notify_service = NotifyService.new
      end

      def create
        @notify_service = NotifyService.new(notify_service_params)

        if @notify_service.save
          NotifyAPIClient.sync_notify_service(notify_service_params)
          redirect_to manage_notify_connections_path, notice: I18n.t("coar_notify.messages.service_created", default: "Notify Service created successfully.")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @notify_service.update(notify_service_params)
          NotifyAPIClient.sync_notify_service(notify_service_params)
          redirect_to manage_notify_connections_path, notice: I18n.t("coar_notify.messages.service_updated", default: "Notify Service updated successfully.")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @notify_service.destroy

        redirect_to manage_notify_connections_path, notice: I18n.t("coar_notify.messages.service_deleted", default: "Notify Service deleted successfully.")
      end

      def request_endorsement
        RequestEndorsementJob.perform_later(
          work_id: params[:work_id],
          service_id: @notify_service.id,
          user_id: current_user.id
        )

        flash[:notice] = I18n.t("coar_notify.request_endorsement_notification.queued", default: "Endorsement request queued successfully.")
        redirect_to (request.referer || main_app.root_path)
      end

      def request_review
        RequestReviewJob.perform_later(
          work_id: params[:work_id],
          service_id: @notify_service.id,
          user_id: current_user.id
        )

        flash[:notice] = I18n.t("coar_notify.request_review_notification.queued", default: "Review request queued successfully.")
        redirect_to (request.referer || main_app.root_path)
      end

      private

      def set_notify_service
        @notify_service = NotifyService.find(params[:id])
      end

      def authorize_admin!
        if respond_to?(:authorize!)
          begin
            authorize! :manage, NotifyService
          rescue CanCan::AccessDenied, StandardError
            authorize! :read, :admin_dashboard rescue nil
          end
        elsif respond_to?(:authenticate_user!)
          authenticate_user!
        end
      end

      def check_duplicate_request
        work_id = params[:work_id]

        if NotifyRequestLogger.duplicate_request?(work_id: work_id, request_type: action_name)
          flash[:alert] = I18n.t("coar_notify.messages.duplicate_request",
                                 request_type: action_name.humanize,
                                 default: "A #{action_name.humanize} request has already been sent for this work.")
          redirect_to (request.referer || main_app.root_path)
        end
      end

      def notify_service_params
        params.require(:notify_service).permit(
          :title,
          :service_url,
          :inbox_url,
          :api_key,
          :status,
          origin_uris: []
        )
      end
    end
  end
end

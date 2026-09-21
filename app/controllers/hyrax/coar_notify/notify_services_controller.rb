# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyServicesController < ApplicationController
      before_action :authorize_manager!, except: [:request_endorsement, :request_review]
      before_action :authorize_work_editor!, only: [:request_endorsement, :request_review]
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

      # Only someone who can edit the work may request an endorsement or review for it.
      def authorize_work_editor!
        work_id = params[:work_id].to_s
        return if work_id.present? && can_edit_work?(work_id)

        raise CanCan::AccessDenied.new(
          I18n.t('coar_notify.messages.not_authorized_to_request',
                 default: 'You are not authorized to request an endorsement or review for this work.'),
          :edit,
          work_id
        )
      end

      # Hydra::Ability raises RecordNotFound for an id it has no permissions document for; treat
      # that as "not allowed" so a made-up work id is refused like any other (and its existence isn't revealed).
      def can_edit_work?(work_id)
        can?(:edit, work_id)
      rescue Blacklight::Exceptions::RecordNotFound
        false
      end

      def set_notify_service
        @notify_service = NotifyService.find(params[:id])
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

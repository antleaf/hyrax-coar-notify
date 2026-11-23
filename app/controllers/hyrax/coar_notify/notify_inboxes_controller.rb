# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyInboxesController < ApplicationController
      before_action :authorize_manager!
      before_action :set_notify_inbox, only: [:edit, :update, :destroy]

      def index
        redirect_to manage_notify_connections_path
      end

      def new
        @notify_inbox = NotifyInbox.new
      end

      def edit
      end

      def create
        @notify_inbox = NotifyInbox.new(notify_inbox_params)

        respond_to do |format|
          if @notify_inbox.save
            format.html { redirect_to manage_notify_connections_path, notice: I18n.t("coar_notify.messages.inbox_created", default: "Notify inbox was successfully created.") }
          else
            format.html { render :new, status: :unprocessable_entity }
          end
        end
      end

      def update
        respond_to do |format|
          if @notify_inbox.update(notify_inbox_params)
            format.html { redirect_to manage_notify_connections_path, notice: I18n.t("coar_notify.messages.inbox_updated", default: "Notify inbox was successfully updated."), status: :see_other }
          else
            format.html { render :edit, status: :unprocessable_entity }
          end
        end
      end

      def destroy
        @notify_inbox.destroy

        respond_to do |format|
          format.html { redirect_to manage_notify_connections_path, notice: I18n.t("coar_notify.messages.inbox_deleted", default: "Notify inbox was successfully destroyed."), status: :see_other }
        end
      end

      private

      def set_notify_inbox
        @notify_inbox = NotifyInbox.find(params[:id])
      end

      def notify_inbox_params
        params.require(:notify_inbox).permit(
          :title,
          :service_url,
          :inbox_url,
          :api_key,
          :status,
          target_uris: []
        )
      end
    end
  end
end

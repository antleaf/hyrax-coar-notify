# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotificationFetcher
      def inbox_url
        Hyrax::CoarNotify.config.inbox_url ||
          "#{Hyrax::CoarNotify.config.base_url || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::BASE_URL : '')}/coar_notify_inbox/notifications"
      end

      def token
        Hyrax::CoarNotify.config.admin_api_token || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::ADMIN_API_TOKEN : nil)
      end

      def call
        response = Faraday.get(inbox_url) do |req|
          req.headers["Authorization"] = "Bearer #{token}" if token.present?
          req.headers["Accept"] = "application/json"
        end

        raise "Failed to fetch notifications" unless response.success?

        notifications = JSON.parse(response.body)
        raise "Unexpected notifications response from #{inbox_url}: expected a list" unless notifications.is_a?(Array)

        notifications.each do |notification|
          save_notification_and_process_relationships(notification)
        rescue StandardError => e
          # One bad notification must not stop the ones after it from being processed.
          Rails.logger.error("COAR Notify: skipped notification #{NotifyRequestLogger.notification_label(notification)}: " \
                             "#{e.class}: #{e.message}")
        end
      end

      private

      def save_notification_and_process_relationships(notification)
        coar_notification = create_or_save_notification(notification)
        return unless coar_notification

        process_relationships(coar_notification, notification)
      end

      def create_or_save_notification(notification)
        NotifyRequestLogger.create_or_update_requests_for_notification(notification)
      end

      def process_relationships(coar_notification, notification)
        status = coar_notification.status
        if ["Announced Endorsement", "Announced Review", "announce_endorsement", "announce_review"].include?(status)
          work_id = coar_notification.work_id
          return if work_id.blank?

          work = begin
            Hyrax.query_service.find_by(id: work_id)
          rescue StandardError => e
            Rails.logger.warn("Could not find work #{work_id} for notification: #{e.message}")
            nil
          end
          return unless work

          service_provider = notification.dig("raw_payload", "origin", "id")

          if status == "Announced Endorsement" || status == "announce_endorsement"
            endorsement = {
              service_provider: service_provider,
              endorsement_url: notification.dig("raw_payload", "object", "id")
            }
            endorsements_list = Array(work.endorsements).dup
            endorsements_list << endorsement.to_json
            work.endorsements = endorsements_list if work.respond_to?(:endorsements=)
            work.has_endorsement = true if work.respond_to?(:has_endorsement=)
          else
            review = {
              service_provider: service_provider,
              review_url: notification.dig("raw_payload", "object", "id")
            }
            reviews_list = Array(work.reviews).dup
            reviews_list << review.to_json
            work.reviews = reviews_list if work.respond_to?(:reviews=)
            work.has_review = true if work.respond_to?(:has_review=)
          end

          if defined?(Hyrax.persister)
            updated_work = Hyrax.persister.save(resource: work)
            Hyrax.index_adapter.save(resource: updated_work) if defined?(Hyrax.index_adapter)
          end
        end
      end
    end
  end
end

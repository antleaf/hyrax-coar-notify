# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotificationFetcher
      Source = Struct.new(:url, :token)

      def call
        sources.each { |source| fetch_and_process(source) }
      end

      private

      # Registered NotifyInbox records the admin has marked active are where notifications are
      # fetched from. With none registered (or none active), fall back to the single inbox from
      # Hyrax::CoarNotify.config, as this always did before more than one inbox could be registered.
      def sources
        active_inboxes = Hyrax::CoarNotify::NotifyInbox.active.to_a
        return active_inboxes.map { |inbox| Source.new(inbox.inbox_url, inbox.api_key) } if active_inboxes.any?

        [Source.new(configured_inbox_url, configured_token)]
      end

      def configured_inbox_url
        Hyrax::CoarNotify.config.inbox_url ||
          "#{Hyrax::CoarNotify.config.base_url || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::BASE_URL : '')}/coar_notify_inbox/notifications"
      end

      def configured_token
        Hyrax::CoarNotify.config.admin_api_token || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::ADMIN_API_TOKEN : nil)
      end

      def fetch_and_process(source)
        response = Faraday.get(source.url) do |req|
          req.headers["Authorization"] = "Bearer #{source.token}" if source.token.present?
          req.headers["Accept"] = "application/json"
        end

        raise "Failed to fetch notifications" unless response.success?

        notifications = JSON.parse(response.body)
        raise "Unexpected notifications response from #{source.url}: expected a list" unless notifications.is_a?(Array)

        notifications.each do |notification|
          save_notification_and_process_relationships(notification)
        rescue StandardError => e
          # One bad notification must not stop the ones after it from being processed.
          Rails.logger.error("COAR Notify: skipped notification #{NotifyRequestLogger.notification_label(notification)}: " \
                             "#{e.class}: #{e.message}")
        end
      end

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
          object_url = notification.dig("raw_payload", "object", "id")

          changed =
            if status == "Announced Endorsement" || status == "announce_endorsement"
              add_entry(work, :endorsements, :has_endorsement, service_provider: service_provider, endorsement_url: object_url)
            else
              add_entry(work, :reviews, :has_review, service_provider: service_provider, review_url: object_url)
            end
          # Already recorded (the inbox served this notification again): nothing to save.
          return unless changed

          if defined?(Hyrax.persister)
            updated_work = Hyrax.persister.save(resource: work)
            Hyrax.index_adapter.save(resource: updated_work) if defined?(Hyrax.index_adapter)
          end
        end
      end

      # Records an endorsement/review on the work unless the same one (same provider and URL) is already
      # there, so processing a notification again does not add it twice. Returns whether the work changed.
      def add_entry(work, list_attribute, flag_attribute, entry)
        current = Array(work.public_send(list_attribute))
        return false if current.any? { |existing| same_entry?(existing, entry) }

        work.public_send("#{list_attribute}=", current.dup << entry.to_json) if work.respond_to?("#{list_attribute}=")
        work.public_send("#{flag_attribute}=", true) if work.respond_to?("#{flag_attribute}=")
        true
      end

      # Entries are stored as JSON strings; an entry that isn't valid JSON can't match anything.
      def same_entry?(existing, entry)
        existing = JSON.parse(existing) if existing.is_a?(String)
        existing.is_a?(Hash) && existing.stringify_keys.slice(*entry.keys.map(&:to_s)) == entry.stringify_keys
      rescue JSON::ParserError
        false
      end
    end
  end
end

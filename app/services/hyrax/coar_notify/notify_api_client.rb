# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyAPIClient
      # Registers this app as a consumer at the external inbox, so notifications from
      # notify_service's origin_uris are routed here. Matches the coar_notify_inbox
      # ConsumersController#create contract (POST /consumers): top-level target_uri and
      # origin_uris, active nested under consumer, and an optional username naming who the
      # consumer belongs to (only takes effect when admin_api_token authenticates as an
      # inbox admin; otherwise the inbox ignores it and uses the token's own user).
      def self.sync_notify_service(notify_service)
        base_url = Hyrax::CoarNotify.config.base_url || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::BASE_URL : nil)
        token = Hyrax::CoarNotify.config.admin_api_token || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::ADMIN_API_TOKEN : nil)

        Faraday.post(
          "#{base_url}/coar_notify_inbox/consumers",
          consumer_payload(notify_service).to_json,
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{token}"
        )
      rescue Faraday::ConnectionFailed => e
        Rails.logger.error("Failed to connect to Notify API: #{e.message}")
        nil
      end

      def self.consumer_payload(notify_service)
        payload = {
          target_uri: application_url,
          origin_uris: Array(notify_service.origin_uris),
          consumer: { active: true }
        }
        payload[:username] = Hyrax::CoarNotify.config.inbox_username if Hyrax::CoarNotify.config.inbox_username.present?
        payload
      end
      private_class_method :consumer_payload

      def self.application_url
        ENV.fetch("APPLICATION_URL", "http://localhost:3000")
      end
      private_class_method :application_url
    end
  end
end

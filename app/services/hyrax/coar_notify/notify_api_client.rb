# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyAPIClient
      def self.sync_notify_service(params)
        base_url = Hyrax::CoarNotify.config.base_url || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::BASE_URL : nil)
        token = Hyrax::CoarNotify.config.admin_api_token || (defined?(CoarNotifyInboxConfig) ? CoarNotifyInboxConfig::ADMIN_API_TOKEN : nil)

        response = Faraday.post(
          "#{base_url}/coar_notify_inbox/consumers",
          params.to_json,
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{token}"
        )
        response
      rescue Faraday::ConnectionFailed => e
        Rails.logger.error("Failed to connect to Notify API: #{e.message}")
        nil
      end
    end
  end
end

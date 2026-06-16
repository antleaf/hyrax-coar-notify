# app/services/notify_api_client.rb

class NotifyAPIClient
  def self.sync_notify_service(params)
    token = CoarNotifyInboxConfig::ADMIN_API_TOKEN
    response = Faraday.post(
      "#{CoarNotifyInboxConfig::API_URL}/coar_notify_inbox/consumers",
      params.to_json,
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    )
    response
  rescue Faraday::ConnectionFailed => e
    Rails.logger.error("Failed to connect to Notify API: #{e.message}")
  end
end
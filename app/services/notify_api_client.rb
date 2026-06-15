# app/services/notify_api_client.rb

class NotifyAPIClient
  def self.sync_notify_service(params)
    Faraday.post(
      "#{CoarNotifyInboxConfig::API_URL}/coar_notify_inbox/senders",
      params.to_json,
      'Content-Type' => 'application/json'
    )
  end
end
# app/services/notify_service_sync.rb

class NotifyServiceSync
  def self.call(notify_service)
    new(notify_service).call
  end

  def initialize(notify_service)
    @notify_service = notify_service
  end

  def call
    if CoarNotifyInboxConfig::USE_LOCAL
      sync_local
    else
      sync_remote
    end
  end

  private

  attr_reader :notify_service

  def sync_local
    notify_service.origin_uris.each do |origin_uri|
      CoarNotify::NotifyConsumer.find_or_create_by(
        service_url: notify_service.service_url,
        origin_uri: origin_uri
      ) do |consumer|
        consumer.title = notify_service.title
        consumer.status = notify_service.status
      end
    end
  end

  def sync_remote
    NotifyAPIClient.sync_notify_service(
      origin_uri: notify_service.origin_uris,
      active: notify_service.active?
    )
  end
end
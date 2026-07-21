# app/services/coar_notify/notification_fetcher.rb

module CoarNotify
  class NotificationFetcher
    URL = "#{CoarNotifyInboxConfig::BASE_URL}/coar_notify_inbox/notifications".freeze
    TOKEN = CoarNotifyInboxConfig::ADMIN_API_TOKEN

    def call
      response = Faraday.get(URL) do |req|
        req.headers["Authorization"] = "Bearer #{TOKEN}"
        req.headers["Accept"] = "application/json"
      end

      raise "Failed to fetch notifications" unless response.success?

      notifications = JSON.parse(response.body)
      notifications.each do |notification|
        save_notification_and_process_relationships(notification)
      end
    end

    private

    def save_notification_and_process_relationships(notification)
      coar_notification = save_notification(notification)
      process_relationships(coar_notification, notification)
    end

    def save_notification(notification)
      NotifyRequestLogger.update_requests_for_notification(notification)
    end

    def process_relationships(coar_notification, notification)
      work_id = NotifyRequestLogger.work_id_from(notification)
      return if work_id.empty?

      work = Hyrax.query_service.find_by(id: work_id)
      return unless work

      work.status = NotifyRequest.statuses.values.include?(notification["type"]) ? notification["type"] : "sent"
      work.note = ''
      work.endorsement_url = notification.dig("object", "id")

      updated_work = Hyrax.persister.save(resource: work)
    end
  end
end
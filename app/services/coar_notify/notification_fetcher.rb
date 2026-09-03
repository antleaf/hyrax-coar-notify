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
      coar_notification = create_or_save_notification(notification)
      return unless coar_notification
      process_relationships(coar_notification, notification)
    end

    def create_or_save_notification(notification)
      NotifyRequestLogger.create_or_update_requests_for_notification(notification)
    end

    def process_relationships(coar_notification, notification)
      status = coar_notification.status
      if ["Announced Endorsement", "Announced Review"].include?(status)
        work_id = coar_notification.work_id
        return if work_id.blank?

        work = Hyrax.query_service.find_by(id: work_id)
        return unless work

        service_provider = notification.dig("raw_payload", "origin", "id")

        if status == "Announced Endorsement"
          work.endorsements << {service_provider: service_provider, endorsement_url: notification.dig("raw_payload", "object", "id")}
          work.has_endorsement = true
        else
          work.reviews << {service_provider: service_provider, review_url: notification.dig("raw_payload", "object", "id")}
          work.has_review = true
        end

        updated_work = Hyrax.persister.save(resource: work)
        Hyrax.index_adapter.save(resource: updated_work)
      end
    end
  end
end
# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyRequestLogger
      # Statuses an incoming notification may put a request into: replies to a request (COAR Notify
      # Accept / Reject / TentativeAccept / TentativeReject), as opposed to "sent", which only we set.
      REPLY_STATUSES = %w[accept tentative_accept reject tentative_reject].freeze

      def self.duplicate_request?(work_id:, request_type:)
        NotifyRequest.where(work_id: work_id.to_s, request_type: request_type).exists?
      end

      def self.log_request!(work:, target:, user:, request_type:, status:, notification_id: nil)
        NotifyRequest.create!(
          work_id: work.id.to_s,
          notify_service_id: target.id,
          user: user,
          request_type: request_type,
          status: status,
          notification_id: notification_id
        )
      end

      def self.create_or_update_requests_for_notification(notification)
        status = notification_status(notification)
        if status.nil?
          Rails.logger.warn("COAR Notify: ignoring notification #{notification_label(notification)} of unsupported type " \
                            "#{notification.dig('raw_payload', 'type').inspect}")
          return
        end

        work_id = work_id_from(notification, status)
        return if work_id.blank?

        request = NotifyRequest.find_by(work_id: work_id)
        return unless request

        request.update(status: status)
        request
      end

      def self.work_id_from(notification, status)
        if status == "announce_endorsement" || status == "announce_review"
          identifier = notification.dig("raw_payload", "context", "id")
          extract_work_id(identifier)
        else
          identifier = notification.dig("raw_payload", "object", "object", "id")
          extract_work_id(identifier)
        end
      end

      def self.extract_work_id(identifier)
        return unless identifier

        identifier = identifier.to_s
        return Regexp.last_match(1) if identifier =~ %r{/concern/[^/]+/([^/?#]+)}

        identifier
      end

      # The status a notification puts its request into, or nil when the notification is of a type this
      # gem does not handle (for example Announce Relationship), so callers can skip it.
      def self.notification_status(notification)
        type = notification.dig("raw_payload", "type")

        if type.is_a?(Array)
          types = type.map(&:to_s)
          return "announce_endorsement" if types.any? { |t| t.include?("EndorsementAction") }
          return "announce_review" if types.any? { |t| t.include?("ReviewAction") }

          nil
        else
          status = type.to_s.underscore
          status if REPLY_STATUSES.include?(status)
        end
      end

      def self.notification_label(notification)
        return notification.to_s[0, 80] unless notification.is_a?(Hash)

        (notification["id"] || notification.dig("raw_payload", "id")).to_s
      end
    end
  end
end

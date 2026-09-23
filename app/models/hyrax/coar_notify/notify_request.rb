# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyRequest < ApplicationRecord
      self.table_name = 'notify_requests'

      belongs_to :notify_service, class_name: 'Hyrax::CoarNotify::NotifyService'
      belongs_to :user, optional: true, class_name: (defined?(::User) ? '::User' : 'User')

      enum :status, {
        "Sent" => "sent",
        "Accepted" => "accept",
        "Tentatively Accepted" => "tentative_accept",
        "Announced Review" => "announce_review",
        "Announced Endorsement" => "announce_endorsement",
        "Rejected" => "reject",
        "Tentatively Rejected" => "tentative_reject"
      }

      validates :work_id, :request_type, :status, presence: true
      validates :request_type, inclusion: { in: ["request_endorsement", "request_review"] }

      scope :with_notifications, -> { where.not(notification_id: nil) }
      scope :without_sent_status, -> { where.not(status: "sent") }
    end
  end
end

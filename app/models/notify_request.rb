class NotifyRequest < ApplicationRecord
  belongs_to :notify_service
  belongs_to :user, optional: true

  enum status: {
    "Sent" => "sent",
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

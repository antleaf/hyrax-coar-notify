class NotifyService < ApplicationRecord
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }

  after_commit :sync_notify_service, on: %i[create update]

  def active?
    status
  end

  private

  def sync_notify_service
    NotifyServiceSync.call(self)
  end
end
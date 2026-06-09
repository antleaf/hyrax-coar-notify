class NotifyService < ApplicationRecord
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }

  def active?
    status
  end
end

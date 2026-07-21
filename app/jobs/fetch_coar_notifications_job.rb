# app/jobs/fetch_coar_notifications_job.rb

class FetchCoarNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    CoarNotify::NotificationFetcher.new.call
  end
end
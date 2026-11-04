# frozen_string_literal: true

module Hyrax
  module CoarNotify
    # Registers FetchNotificationsJob to run on config.fetch_schedule via sidekiq-scheduler, if the
    # host has that gem loaded. Uses Sidekiq.set_schedule (not Sidekiq.schedule=), which only
    # creates/updates this one named entry, leaving any other jobs the host has scheduled alone.
    # Hosts without sidekiq-scheduler get no automatic scheduling and must trigger the job
    # themselves (see README).
    module Scheduler
      SCHEDULE_NAME = "hyrax_coar_notify_fetch_notifications"

      def self.register!
        return unless schedulable?

        Sidekiq.configure_server do
          Sidekiq.set_schedule(SCHEDULE_NAME, schedule_entry)
        end
      end

      # set_schedule is added to Sidekiq by sidekiq-scheduler's extension; checking for it (rather
      # than just `defined?(Sidekiq)`) tells apart plain sidekiq from sidekiq-scheduler being loaded.
      def self.schedulable?
        defined?(Sidekiq) && Sidekiq.respond_to?(:set_schedule)
      end

      def self.schedule_entry
        {
          "cron" => Hyrax::CoarNotify.config.fetch_schedule,
          "class" => "Hyrax::CoarNotify::FetchNotificationsJob"
        }
      end
    end
  end
end

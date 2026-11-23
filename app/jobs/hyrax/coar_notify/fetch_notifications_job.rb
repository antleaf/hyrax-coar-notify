# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class FetchNotificationsJob < ApplicationJob
      queue_as :default

      def perform
        NotificationFetcher.new.call
      end
    end
  end
end

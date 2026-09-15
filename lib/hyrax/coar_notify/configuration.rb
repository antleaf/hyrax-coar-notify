# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class Configuration
      attr_accessor :base_url,
                    :admin_api_token,
                    :use_local,
                    :inbox_url,
                    :default_origin_inbox,
                    :fetch_schedule

      def initialize
        @use_local = ENV.fetch('COAR_NOTIFY_USE_LOCAL', 'true') == 'true'
        @base_url = ENV['COAR_NOTIFY_BASE_URL']
        @admin_api_token = ENV['COAR_NOTIFY_ADMIN_API_TOKEN']
        @inbox_url = ENV['COAR_NOTIFY_INBOX_URL']
        @default_origin_inbox = ENV['COAR_NOTIFY_DEFAULT_ORIGIN_INBOX']
        @fetch_schedule = '*/5 * * * *'
      end
    end
  end
end

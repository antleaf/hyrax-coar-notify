# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class Configuration
      attr_accessor :base_url,
                    :admin_api_token,
                    :use_local,
                    :inbox_url,
                    :default_origin_inbox,
                    :fetch_schedule,
                    :manager_role,
                    :inbox_username,
                    :allow_local_origin

      def initialize
        @use_local = ENV.fetch('COAR_NOTIFY_USE_LOCAL', 'true') == 'true'
        @base_url = ENV['COAR_NOTIFY_BASE_URL']
        @admin_api_token = ENV['COAR_NOTIFY_ADMIN_API_TOKEN']
        @inbox_url = ENV['COAR_NOTIFY_INBOX_URL']
        @default_origin_inbox = ENV['COAR_NOTIFY_DEFAULT_ORIGIN_INBOX']
        @fetch_schedule = '*/5 * * * *'
        @manager_role = ENV.fetch('NOTIFY_MANAGER_ROLE', 'admin')
        @inbox_username = ENV['COAR_NOTIFY_INBOX_USERNAME']
        # When false (the default) a request is refused if this repository's own URLs point at
        # localhost, a loopback or a private address, since the target service cannot reach them.
        # Set COAR_NOTIFY_ALLOW_LOCAL_ORIGIN=true for development against a local inbox.
        @allow_local_origin = ENV.fetch('COAR_NOTIFY_ALLOW_LOCAL_ORIGIN', 'false') == 'true'
      end
    end
  end
end

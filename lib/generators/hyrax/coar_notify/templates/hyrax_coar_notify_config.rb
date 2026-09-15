# frozen_string_literal: true

Hyrax::CoarNotify.configure do |config|
  # Base URL of the COAR Notify Inbox service / host application
  config.base_url = ENV.fetch('COAR_NOTIFY_BASE_URL', 'http://localhost:3000')

  # Admin API Token for authenticating with the COAR Notify Inbox API
  config.admin_api_token = ENV.fetch('COAR_NOTIFY_ADMIN_API_TOKEN', nil)

  # Explicit inbox notifications URL (defaults to #{base_url}/coar_notify_inbox/notifications)
  # config.inbox_url = "#{config.base_url}/coar_notify_inbox/notifications"

  # Whether to use local inbox handling
  config.use_local = ENV.fetch('COAR_NOTIFY_USE_LOCAL', 'true') == 'true'

  # Cron schedule for the notifications fetcher background job
  # config.fetch_schedule = '*/5 * * * *'
end

module CoarNotifyInboxConfig
  USE_LOCAL = ENV.fetch('COAR_NOTIFY_USE_LOCAL', 'true') == 'true'
  API_URL = ENV['COAR_NOTIFY_API_URL']
end
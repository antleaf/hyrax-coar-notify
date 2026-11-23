# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require 'hyrax'
require 'hyrax/coar_notify'

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.load_defaults 7.2
    config.add_autoload_paths_to_load_path = true
    config.eager_load = false
    config.secret_key_base = 'a_test_secret_key_base_for_dummy_app_running_rspec_specs_123456789'
    config.active_job.queue_adapter = :test
  end
end

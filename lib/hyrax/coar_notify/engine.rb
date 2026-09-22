# frozen_string_literal: true

require 'rails/engine'

module Hyrax
  module CoarNotify
    class Engine < ::Rails::Engine
      isolate_namespace Hyrax::CoarNotify

      initializer 'hyrax_coar_notify.assets' do |app|
        # Register view paths or assets if needed
      end

      initializer 'hyrax_coar_notify.scheduler' do
        Hyrax::CoarNotify::Scheduler.register!
      end

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot
      end
    end
  end
end

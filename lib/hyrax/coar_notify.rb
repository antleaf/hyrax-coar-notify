# frozen_string_literal: true

require 'hyrax/coar_notify/version'
require 'hyrax/coar_notify/configuration'
require 'hyrax/coar_notify/engine'

module Hyrax
  module CoarNotify
    class << self
      def configuration
        @configuration ||= Configuration.new
      end
      alias config configuration

      def configure
        yield(configuration) if block_given?
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end

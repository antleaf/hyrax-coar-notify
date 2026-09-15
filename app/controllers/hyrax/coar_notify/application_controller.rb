# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class ApplicationController < ::ApplicationController
      helper Hyrax::Engine.helpers if defined?(Hyrax::Engine)
      with_themed_layout 'dashboard' if respond_to?(:with_themed_layout)
    end
  end
end

# frozen_string_literal: true
# Patch for coar_notify_inbox gem to support Rails 7.2
# This file patches the migration compatibility issue with the gem

if defined?(ActiveRecord::Migration::Compatibility)
  module ActiveRecord::Migration::Compatibility
    class << self
      prepend Module.new {
        def find(version)
          # Allow Rails 8.0 migrations to run on Rails 7.2
          version = "7.2" if version.to_s == "8.0"
          super(version)
        end
      }
    end
  end
end

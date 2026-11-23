# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyService < ApplicationRecord
      self.table_name = 'notify_services'

      serialize :origin_uris, type: Array, coder: YAML unless connection_db_config.adapter.include?('postgresql') rescue nil

      scope :active, -> { where(status: true) }
      scope :inactive, -> { where(status: false) }

      def active?
        status
      end
    end
  end
end

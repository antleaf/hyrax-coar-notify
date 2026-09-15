# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class NotifyInbox < ApplicationRecord
      self.table_name = 'notify_inboxes'

      serialize :target_uris, type: Array, coder: YAML unless connection_db_config.adapter.include?('postgresql') rescue nil

      scope :active, -> { where(status: true) }
      scope :inactive, -> { where(status: false) }

      def active?
        status
      end
    end
  end
end

# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class ApplicationRecord < ::ActiveRecord::Base
      self.abstract_class = true
    end
  end
end

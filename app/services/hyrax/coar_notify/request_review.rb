# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class RequestReview < RequestBase
      REQUEST_TYPE = "request_review".freeze
      ACTIVITY_TYPE = %w[Offer coar-notify:ReviewAction].freeze
      I18N_SCOPE = "coar_notify.request_review_notification".freeze
      ACTION_NOUN = "Review".freeze
    end
  end
end

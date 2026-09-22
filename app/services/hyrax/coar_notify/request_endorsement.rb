# frozen_string_literal: true

module Hyrax
  module CoarNotify
    class RequestEndorsement < RequestBase
      REQUEST_TYPE = "request_endorsement".freeze
      ACTIVITY_TYPE = %w[Offer coar-notify:EndorsementAction].freeze
      I18N_SCOPE = "coar_notify.request_endorsement_notification".freeze
      ACTION_NOUN = "Endorsement".freeze
    end
  end
end

# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Dataset`
class Dataset < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:dataset)

  def duplicate_endorsement_request?
    NotifyRequestLogger.duplicate_request?(
      work_id: self.id.to_s,
      request_type: RequestEndorsement::REQUEST_TYPE
    )
  end

  def duplicate_review_request?
    NotifyRequestLogger.duplicate_request?(
      work_id: self.id.to_s,
      notify_service_id: target.id,
      request_type: RequestReview::REQUEST_TYPE
    )
  end
end

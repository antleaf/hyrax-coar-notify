# frozen_string_literal: true

module Hyrax
  module CoarNotify
    module WorkBehavior
      extend ActiveSupport::Concern

      def duplicate_endorsement_request?
        NotifyRequestLogger.duplicate_request?(
          work_id: id.to_s,
          request_type: RequestEndorsement::REQUEST_TYPE
        )
      end

      def duplicate_review_request?
        NotifyRequestLogger.duplicate_request?(
          work_id: id.to_s,
          request_type: RequestReview::REQUEST_TYPE
        )
      end

      def parsed_endorsements
        return [] unless respond_to?(:endorsements) && endorsements.present?

        Array(endorsements).map do |endorsement|
          endorsement.is_a?(String) ? JSON.parse(endorsement) : endorsement
        rescue JSON::ParserError
          endorsement
        end
      end

      def parsed_reviews
        return [] unless respond_to?(:reviews) && reviews.present?

        Array(reviews).map do |review|
          review.is_a?(String) ? JSON.parse(review) : review
        rescue JSON::ParserError
          review
        end
      end
    end
  end
end

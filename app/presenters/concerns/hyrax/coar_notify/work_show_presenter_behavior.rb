# frozen_string_literal: true

module Hyrax
  module CoarNotify
    module WorkShowPresenterBehavior
      extend ActiveSupport::Concern

      # Solr field names for the attributes defined by the install generator's
      # coar_notify_metadata.yaml. A plain SolrDocument has no reader methods for these (they're
      # resource attributes, not SolrDocument accessors), so they're read straight from Solr instead.
      ENDORSEMENTS_FIELD = "endorsements_tesim"
      REVIEWS_FIELD = "reviews_tesim"
      HAS_ENDORSEMENT_FIELD = "has_endorsement_bsi"
      HAS_REVIEW_FIELD = "has_review_bsi"

      def notify_services
        @notify_services ||= Hyrax::CoarNotify::NotifyService.active.order(created_at: :desc)
      end

      # Only people who can edit the work may request an endorsement or review.
      # Fails closed when the including presenter has no #editor? (Hyrax::WorkShowPresenter does).
      def can_request_notify?
        respond_to?(:editor?) && editor? ? true : false
      end

      def parsed_endorsements
        parse_entries(solr_document[ENDORSEMENTS_FIELD])
      end

      def parsed_reviews
        parse_entries(solr_document[REVIEWS_FIELD])
      end

      def endorsements
        parsed_endorsements
      end

      def reviews
        parsed_reviews
      end

      def has_endorsement?
        endorsements.any? || truthy?(solr_document[HAS_ENDORSEMENT_FIELD])
      end

      def has_review?
        reviews.any? || truthy?(solr_document[HAS_REVIEW_FIELD])
      end

      private

      def parse_entries(values)
        Array(values).map do |entry|
          entry.is_a?(String) ? JSON.parse(entry) : entry
        rescue JSON::ParserError
          entry
        end
      end

      def truthy?(value)
        value == true || value.to_s == 'true'
      end
    end
  end
end

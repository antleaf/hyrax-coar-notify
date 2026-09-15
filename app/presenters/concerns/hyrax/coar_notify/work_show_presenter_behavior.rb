# frozen_string_literal: true

module Hyrax
  module CoarNotify
    module WorkShowPresenterBehavior
      extend ActiveSupport::Concern

      def notify_services
        @notify_services ||= Hyrax::CoarNotify::NotifyService.active.order(created_at: :desc)
      end

      def parsed_endorsements
        if solr_document.respond_to?(:parsed_endorsements)
          solr_document.parsed_endorsements
        elsif solr_document.respond_to?(:endorsements) && solr_document.endorsements.present?
          Array(solr_document.endorsements).map do |e|
            e.is_a?(String) ? JSON.parse(e) : e
          rescue JSON::ParserError
            e
          end
        else
          []
        end
      end

      def parsed_reviews
        if solr_document.respond_to?(:parsed_reviews)
          solr_document.parsed_reviews
        elsif solr_document.respond_to?(:reviews) && solr_document.reviews.present?
          Array(solr_document.reviews).map do |r|
            r.is_a?(String) ? JSON.parse(r) : r
          rescue JSON::ParserError
            r
          end
        else
          []
        end
      end

      def endorsements
        parsed_endorsements
      end

      def reviews
        parsed_reviews
      end

      def has_endorsement?
        endorsements.any? || solr_document.try(:has_endorsement) == true || solr_document.try(:has_endorsement) == 'true'
      end

      def has_review?
        reviews.any? || solr_document.try(:has_review) == true || solr_document.try(:has_review) == 'true'
      end
    end
  end
end

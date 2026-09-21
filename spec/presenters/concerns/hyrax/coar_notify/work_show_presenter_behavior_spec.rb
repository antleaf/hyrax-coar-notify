# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::WorkShowPresenterBehavior do
  let(:dummy_solr_doc) do
    double(
      'SolrDocument',
      endorsements: ['{"service_provider":"https://service.org","endorsement_url":"https://service.org/1"}'],
      reviews: ['{"service_provider":"https://service.org","review_url":"https://service.org/rev/1"}'],
      has_endorsement: true,
      has_review: true
    )
  end

  let(:dummy_presenter_class) do
    Class.new do
      include Hyrax::CoarNotify::WorkShowPresenterBehavior

      attr_reader :solr_document

      def initialize(solr_document)
        @solr_document = solr_document
      end
    end
  end

  let(:presenter) { dummy_presenter_class.new(dummy_solr_doc) }

  it 'provides parsed endorsements and reviews' do
    expect(presenter.parsed_endorsements.first['service_provider']).to eq('https://service.org')
    expect(presenter.parsed_reviews.first['review_url']).to eq('https://service.org/rev/1')
    expect(presenter.has_endorsement?).to be true
    expect(presenter.has_review?).to be true
  end

  describe '#can_request_notify?' do
    it 'is true when the presenter says the viewer can edit' do
      editor_class = Class.new(dummy_presenter_class) { def editor? = true }
      expect(editor_class.new(dummy_solr_doc).can_request_notify?).to be true
    end

    it 'is false when the viewer cannot edit' do
      viewer_class = Class.new(dummy_presenter_class) { def editor? = false }
      expect(viewer_class.new(dummy_solr_doc).can_request_notify?).to be false
    end

    it 'fails closed when the presenter has no #editor?' do
      expect(presenter.can_request_notify?).to be false
    end
  end
end

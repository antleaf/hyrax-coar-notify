# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::WorkBehavior do
  let(:dummy_work_class) do
    Class.new do
      include Hyrax::CoarNotify::WorkBehavior

      attr_accessor :id, :endorsements, :reviews

      def initialize(id: 'work-99', endorsements: [], reviews: [])
        @id = id
        @endorsements = endorsements
        @reviews = reviews
      end
    end
  end

  let(:work) do
    dummy_work_class.new(
      endorsements: ['{"service_provider":"https://service.org","endorsement_url":"https://service.org/endorse/1"}'],
      reviews: ['{"service_provider":"https://service.org","review_url":"https://service.org/review/1"}']
    )
  end

  it 'parses stored json endorsements and reviews' do
    expect(work.parsed_endorsements.first['service_provider']).to eq('https://service.org')
    expect(work.parsed_reviews.first['review_url']).to eq('https://service.org/review/1')
  end
end

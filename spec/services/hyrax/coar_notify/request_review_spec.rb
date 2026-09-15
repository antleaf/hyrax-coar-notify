# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Hyrax::CoarNotify::RequestReview do
  let(:service) do
    Hyrax::CoarNotify::NotifyService.create!(
      title: 'Peer Review Service',
      service_url: 'https://review.peercommunityin.org',
      inbox_url: 'https://review.peercommunityin.org/coar_notify/inbox',
      api_key: 'review_token',
      status: true
    )
  end

  let(:user) { User.create!(email: 'author@example.org', password: 'password123', display_name: 'Author Name') }

  let(:file_set) do
    double(
      'FileSet',
      id: 'fs-999',
      file_set?: true,
      original_file: double('OriginalFile', mime_type: 'application/pdf')
    )
  end

  let(:work) do
    double(
      'DatasetWork',
      id: 'work-dataset-789',
      doi: '10.1234/example.review.doi',
      identifier: ['10.1234/example.review.doi'],
      depositor: 'author@example.org',
      class: double('WorkClass', to_s: 'Dataset')
    )
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('APPLICATION_URL', anything).and_return('https://repository.example.org')
    allow(ENV).to receive(:fetch).with('APPLICATION_URL').and_return('https://repository.example.org')

    allow(Hyrax.query_service).to receive(:find_members).with(resource: work).and_return([file_set])
  end

  describe '#call' do
    it 'posts a valid review request ActivityStreams payload' do
      stub_request(:post, 'https://review.peercommunityin.org/coar_notify/inbox')
        .with(
          headers: {
            'Content-Type' => 'application/ld+json',
            'Authorization' => 'Bearer review_token'
          }
        )
        .to_return(status: 201, body: '{"status":"received"}', headers: {})

      expect {
        described_class.new(work: work, target: service, user: user).call
      }.to change { Hyrax::CoarNotify::NotifyRequest.count }.by(1)

      logged_request = Hyrax::CoarNotify::NotifyRequest.last
      expect(logged_request.work_id).to eq('work-dataset-789')
      expect(logged_request.request_type).to eq('request_review')
      expect(logged_request.status).to eq('Sent')
    end
  end
end

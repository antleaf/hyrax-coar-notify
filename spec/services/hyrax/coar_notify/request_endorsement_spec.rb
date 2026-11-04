# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Hyrax::CoarNotify::RequestEndorsement do
  let(:service) do
    Hyrax::CoarNotify::NotifyService.create!(
      title: 'Peer Community In Evolutionary Biology',
      service_url: 'https://evolbiol.peercommunityin.org',
      inbox_url: 'https://evolbiol.peercommunityin.org/coar_notify/inbox',
      api_key: 'test_token',
      status: true
    )
  end

  let(:user) { User.create!(email: 'author@example.org', password: 'password123', display_name: 'Author Name') }

  let(:file_set) do
    double(
      'FileSet',
      id: 'fs-123',
      file_set?: true,
      original_file: double('OriginalFile', mime_type: 'application/pdf')
    )
  end

  let(:work) do
    double(
      'DatasetWork',
      id: 'work-dataset-456',
      doi: '10.1234/example.doi',
      identifier: ['10.1234/example.doi'],
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
    it 'posts a valid COAR Notify ActivityStreams payload to the target inbox' do
      stub_request(:post, 'https://evolbiol.peercommunityin.org/coar_notify/inbox')
        .with(
          headers: {
            'Content-Type' => 'application/ld+json',
            'Authorization' => 'Bearer test_token'
          }
        )
        .to_return(status: 201, body: '{"status":"created"}', headers: {})

      expect {
        described_class.new(work: work, target: service, user: user).call
      }.to change { Hyrax::CoarNotify::NotifyRequest.count }.by(1)

      logged_request = Hyrax::CoarNotify::NotifyRequest.last
      expect(logged_request.work_id).to eq('work-dataset-456')
      expect(logged_request.request_type).to eq('request_endorsement')
      expect(logged_request.status).to eq('Sent')
    end
  end

  describe 'the request id' do
    let(:other_work) do
      double('OtherWork', id: 'work-dataset-other', doi: '10.1234/other', identifier: ['10.1234/other'],
                          depositor: 'author@example.org', class: double('WorkClass', to_s: 'Dataset'))
    end
    let(:inbox) { service.inbox_url }

    before do
      allow(Hyrax.query_service).to receive(:find_members).with(resource: other_work).and_return([file_set])
      stub_request(:post, inbox).to_return(status: 201, body: '{}')
    end

    def sent_ids
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys.map { |sig| JSON.parse(sig.body)['id'] }
    end

    it 'sends a fresh urn:uuid id with each request and stores exactly that id' do
      described_class.new(work: work, target: service, user: user).call
      described_class.new(work: other_work, target: service, user: user).call

      stored = Hyrax::CoarNotify::NotifyRequest.order(:id).pluck(:notification_id)
      expect(stored).to all(match(/\Aurn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/))
      expect(stored.uniq.size).to eq(2)
      expect(sent_ids).to match_array(stored)
    end

    it 'does not derive the id from the work, so it cannot collide with another kind of request' do
      described_class.new(work: work, target: service, user: user).call
      expect(Hyrax::CoarNotify::NotifyRequest.last.notification_id).not_to include(work.id)
    end
  end

  describe '#call when the target responds with an error' do
    let(:inbox) { service.inbox_url }

    before { allow(Hyrax::MessengerService).to receive(:deliver) if defined?(Hyrax::MessengerService) }

    it 'does not record a NotifyRequest for a 4xx response' do
      stub_request(:post, inbox).to_return(status: 422, body: '{"error":"invalid target"}')
      expect { described_class.new(work: work, target: service, user: user).call }
        .not_to change(Hyrax::CoarNotify::NotifyRequest, :count)
    end

    it 'does not record a NotifyRequest for a 5xx response' do
      stub_request(:post, inbox).to_return(status: 503, body: 'unavailable')
      expect { described_class.new(work: work, target: service, user: user).call }
        .not_to change(Hyrax::CoarNotify::NotifyRequest, :count)
    end

    it 'reports the failure, including the response body, rather than success' do
      stub_request(:post, inbox).to_return(status: 422, body: '{"error":"invalid target"}')
      expect(Hyrax::MessengerService).to receive(:deliver) do |_user, _recipients, message, _subject|
        expect(message).to include('422')
        expect(message).to include('invalid target')
        expect(message).not_to include('successfully')
      end
      described_class.new(work: work, target: service, user: user).call
    end

    it 'lets the request be sent again, since nothing was recorded as sent' do
      stub_request(:post, inbox).to_return({ status: 500 }, { status: 201, body: '{}' })
      2.times { described_class.new(work: work, target: service, user: user).call }
      expect(Hyrax::CoarNotify::NotifyRequest.count).to eq(1)
      expect(Hyrax::CoarNotify::NotifyRequest.last.status).to eq('Sent')
    end
  end

  describe '#call when the target accepts the request' do
    it 'still records and reports success for a non-201 success status' do
      stub_request(:post, service.inbox_url).to_return(status: 200, body: '{}')
      allow(Hyrax::MessengerService).to receive(:deliver) if defined?(Hyrax::MessengerService)
      described_class.new(work: work, target: service, user: user).call
      expect(Hyrax::CoarNotify::NotifyRequest.last.status).to eq('Sent')
    end
  end

  describe '#call when something outside the rescued classes goes wrong' do
    it 'notifies the user and still lets the error propagate, so the job is marked failed' do
      allow(Hyrax.query_service).to receive(:find_members).and_raise(NoMemoryError, 'out of memory')
      allow(Hyrax::MessengerService).to receive(:deliver) if defined?(Hyrax::MessengerService)

      expect { described_class.new(work: work, target: service, user: user).call }.to raise_error(NoMemoryError)
      expect(Hyrax::MessengerService).to have_received(:deliver).with(anything, anything, a_string_including('out of memory'), anything) if defined?(Hyrax::MessengerService)
    end
  end
end

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
    Hyrax::CoarNotify.config.inbox_url = 'https://repository.example.org/coar_notify_inbox/notifications'
  end

  after { Hyrax::CoarNotify.reset_configuration! }

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

  describe 'the payload' do
    it 'types the object as an ActivityStreams Page, as in the COAR Notify examples' do
      stub = stub_request(:post, service.inbox_url)
             .with { |req| JSON.parse(req.body).dig('object', 'type') == %w[Page sorg:AboutPage] }
             .to_return(status: 201, body: '{}')

      described_class.new(work: work, target: service, user: user).call

      expect(stub).to have_been_requested
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

  describe '#call when this repository is not publicly reachable' do
    let(:messages) { [] }

    before do
      allow(Hyrax::MessengerService).to receive(:deliver) { |_u, _r, message, _s| messages << message } if defined?(Hyrax::MessengerService)
    end

    def call_with_application_url(url)
      allow(ENV).to receive(:fetch).with('APPLICATION_URL', anything).and_return(url)
      allow(ENV).to receive(:fetch).with('APPLICATION_URL').and_return(url)
      described_class.new(work: work, target: service, user: user).call
    end

    [
      'http://localhost:3000', 'http://LOCALHOST', 'http://127.0.0.1:3000', 'http://127.5.5.5',
      'http://[::1]:3000', 'http://0.0.0.0:3000', 'http://10.1.2.3', 'http://172.16.0.9',
      'http://172.31.255.1', 'http://192.168.1.20:3000', 'http://169.254.10.10',
      'http://myhost.local', 'http://app.localhost:3000', ''
    ].each do |url|
      it "refuses to send, tells the user and records nothing when APPLICATION_URL is #{url.inspect}" do
        stub = stub_request(:post, service.inbox_url)
        expect { call_with_application_url(url) }.not_to change(Hyrax::CoarNotify::NotifyRequest, :count)
        expect(stub).not_to have_been_requested
        expect(messages.join).to include('not publicly reachable').and include('APPLICATION_URL')
      end
    end

    it 'refuses to send when only the origin inbox URL is local' do
      Hyrax::CoarNotify.config.inbox_url = 'http://localhost:3001/coar_notify_inbox/notifications'
      stub = stub_request(:post, service.inbox_url)
      described_class.new(work: work, target: service, user: user).call
      expect(stub).not_to have_been_requested
      expect(messages.join).to include('origin inbox URL')
    end

    it 'sends normally for a public hostname or public IP address' do
      %w[https://repository.example.org http://8.8.8.8 http://172.32.0.1 https://[2001:db8::1]].each do |url|
        Hyrax::CoarNotify::NotifyRequest.delete_all
        stub = stub_request(:post, service.inbox_url).to_return(status: 201, body: '{}')
        call_with_application_url(url)
        expect(stub).to have_been_requested.at_least_once
      end
    end

    it 'sends to a local origin when allow_local_origin is enabled' do
      Hyrax::CoarNotify.config.allow_local_origin = true
      Hyrax::CoarNotify.config.inbox_url = 'http://localhost:3001/coar_notify_inbox/notifications'
      stub = stub_request(:post, service.inbox_url).to_return(status: 201, body: '{}')
      call_with_application_url('http://localhost:3000')
      expect(stub).to have_been_requested
      expect(Hyrax::CoarNotify::NotifyRequest.last.status).to eq('Sent')
    end
  end

  describe '#call when the target does not respond in time' do
    let(:messages) { [] }

    before do
      allow(Hyrax::MessengerService).to receive(:deliver) { |_u, _r, message, _s| messages << message } if defined?(Hyrax::MessengerService)
      stub_request(:post, service.inbox_url).to_timeout
    end

    it 'tells the user the service did not respond in time, without raising or a stack trace' do
      expect { described_class.new(work: work, target: service, user: user).call }.not_to raise_error
      expect(messages.join).to include('did not respond in time').and include(service.title)
    end

    it 'gives the same message when the connection was made but the response timed out' do
      stub_request(:post, service.inbox_url).to_raise(Net::ReadTimeout)
      expect { described_class.new(work: work, target: service, user: user).call }.not_to raise_error
      expect(messages.join).to include('did not respond in time')
    end

    it 'records no NotifyRequest, so the request can be tried again' do
      expect { described_class.new(work: work, target: service, user: user).call }
        .not_to change(Hyrax::CoarNotify::NotifyRequest, :count)
    end
  end
end

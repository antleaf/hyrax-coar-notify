# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Hyrax::CoarNotify::NotifyAPIClient do
  let(:notify_service) do
    Hyrax::CoarNotify::NotifyService.create!(title: 'PCI', service_url: 'https://pci.test', inbox_url: 'https://pci.test/inbox',
                                             status: true, origin_uris: ['https://pci.test/origin', 'https://other.test'])
  end

  before do
    Hyrax::CoarNotify.configure do |config|
      config.base_url = 'https://inbox.test'
      config.admin_api_token = 'admin-token'
      config.inbox_username = nil
    end
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('APPLICATION_URL', anything).and_return('https://repository.example.org')
  end

  after { Hyrax::CoarNotify.reset_configuration! }

  def stub_consumers(status: 201, body: '{}')
    stub_request(:post, 'https://inbox.test/coar_notify_inbox/consumers').to_return(status: status, body: body)
  end

  def sent_payload
    request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
    JSON.parse(request.body)
  end

  describe '.sync_notify_service' do
    it 'sends the payload the coar_notify_inbox consumers API expects: target_uri and origin_uris at the ' \
       'top level, active nested under consumer' do
      stub_consumers
      described_class.sync_notify_service(notify_service)

      expect(sent_payload).to eq(
        'target_uri' => 'https://repository.example.org',
        'origin_uris' => ['https://pci.test/origin', 'https://other.test'],
        'consumer' => { 'active' => true }
      )
    end

    it 'does not send a username when none is configured' do
      stub_consumers
      described_class.sync_notify_service(notify_service)
      expect(sent_payload).not_to have_key('username')
    end

    it 'sends the configured inbox username' do
      Hyrax::CoarNotify.config.inbox_username = 'hyrax-notify-bot'
      stub_consumers
      described_class.sync_notify_service(notify_service)
      expect(sent_payload['username']).to eq('hyrax-notify-bot')
    end

    it 'authenticates with the admin API token as a bearer token, over JSON' do
      stub_consumers
      described_class.sync_notify_service(notify_service)
      expect(WebMock).to have_requested(:post, 'https://inbox.test/coar_notify_inbox/consumers')
        .with(headers: { 'Authorization' => 'Bearer admin-token', 'Content-Type' => 'application/json' })
    end

    it 'returns the response' do
      stub_consumers(status: 201, body: '{"id":1}')
      expect(described_class.sync_notify_service(notify_service).status).to eq(201)
    end

    it 'returns nil and logs, rather than raising, when the inbox cannot be reached' do
      stub_request(:post, 'https://inbox.test/coar_notify_inbox/consumers').to_raise(Faraday::ConnectionFailed.new('refused'))
      allow(Rails.logger).to receive(:error)
      expect(described_class.sync_notify_service(notify_service)).to be_nil
      expect(Rails.logger).to have_received(:error).with(/refused/)
    end

    it 'sends an empty list, not nil, when the service has no origin_uris' do
      notify_service.update!(origin_uris: [])
      stub_consumers
      described_class.sync_notify_service(notify_service)
      expect(sent_payload['origin_uris']).to eq([])
    end
  end
end

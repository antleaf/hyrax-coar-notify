# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Hyrax::CoarNotify::NotificationFetcher do
  let(:service) do
    Hyrax::CoarNotify::NotifyService.create!(
      title: 'PCI Evolutionary Biology',
      service_url: 'https://evolbiol.peercommunityin.org',
      inbox_url: 'https://evolbiol.peercommunityin.org/inbox',
      status: true
    )
  end

  let!(:notify_request) do
    Hyrax::CoarNotify::NotifyRequest.create!(
      work_id: 'work-valkyrie-101',
      notify_service: service,
      request_type: 'request_endorsement',
      status: 'sent',
      notification_id: 'urn:uuid:notification-101'
    )
  end

  let(:work_double) do
    double(
      'Work',
      id: 'work-valkyrie-101',
      endorsements: [],
      reviews: [],
      respond_to?: true
    )
  end

  before do
    Hyrax::CoarNotify.configure do |config|
      config.inbox_url = 'https://repository.example.org/coar_notify_inbox/notifications'
      config.admin_api_token = 'admin_token'
    end
  end

  describe '#call' do
    let(:inbound_notifications) do
      [
        {
          "id" => "urn:uuid:announce-endorsement-1",
          "raw_payload" => {
            "type" => ["Announce", "coar-notify:EndorsementAction"],
            "origin" => { "id" => "https://evolbiol.peercommunityin.org" },
            "context" => { "id" => "https://repository.example.org/concern/datasets/work-valkyrie-101" },
            "object" => { "id" => "https://evolbiol.peercommunityin.org/articles/rec-123" }
          }
        }
      ]
    end

    it 'fetches notifications from inbox and updates notify_requests status' do
      stub_request(:get, 'https://repository.example.org/coar_notify_inbox/notifications')
        .with(headers: { 'Authorization' => 'Bearer admin_token', 'Accept' => 'application/json' })
        .to_return(status: 200, body: inbound_notifications.to_json, headers: { 'Content-Type' => 'application/json' })

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-valkyrie-101').and_return(nil)

      expect {
        described_class.new.call
      }.not_to raise_error

      notify_request.reload
      expect(notify_request.status).to eq('Announced Endorsement')
    end
  end

  describe '#call with a mixed inbox' do
    let(:inbox) { 'https://repository.example.org/coar_notify_inbox/notifications' }
    let(:accept) do
      { 'id' => 'urn:uuid:accept-1',
        'raw_payload' => { 'type' => 'Accept',
                           'object' => { 'object' => { 'id' => 'https://repository.example.org/concern/datasets/work-valkyrie-101' } } } }
    end
    let(:relationship) do
      { 'id' => 'urn:uuid:relationship-1',
        'raw_payload' => { 'type' => ['Announce', 'coar-notify:RelationshipAction'],
                           'context' => { 'id' => 'https://repository.example.org/concern/datasets/work-valkyrie-101' },
                           'object' => { 'id' => 'https://other.example.org/x' } } }
    end

    def serve(body)
      stub_request(:get, inbox).to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)
    end

    it 'records an Accept without raising' do
      serve([accept])
      expect { described_class.new.call }.not_to raise_error
      expect(notify_request.reload.status).to eq('Accepted')
    end

    it 'skips an unsupported notification without changing the request' do
      serve([relationship])
      expect { described_class.new.call }.not_to raise_error
      expect(notify_request.reload.status).to eq('Sent')
    end

    it 'logs a notification it cannot process and still processes the ones after it' do
      serve(['not a notification', nil, accept])
      expect { described_class.new.call }.not_to raise_error
      expect(notify_request.reload.status).to eq('Accepted')
      expect(Rails.logger).to have_received(:error).twice
    end

    it 'keeps going when processing one notification raises' do
      serve([accept, accept.merge('id' => 'urn:uuid:accept-2')])
      calls = 0
      allow(Hyrax::CoarNotify::NotifyRequestLogger).to receive(:create_or_update_requests_for_notification).and_wrap_original do |m, n|
        calls += 1
        raise 'boom' if calls == 1

        m.call(n)
      end
      expect { described_class.new.call }.not_to raise_error
      expect(notify_request.reload.status).to eq('Accepted')
      expect(Rails.logger).to have_received(:error).with(/skipped notification urn:uuid:accept-1: RuntimeError: boom/)
    end

    it 'still fails the whole run when the inbox cannot be read' do
      stub_request(:get, inbox).to_return(status: 500)
      expect { described_class.new.call }.to raise_error(/Failed to fetch notifications/)
    end

    it 'fails the run when the inbox does not return a list' do
      serve('error' => 'nope')
      expect { described_class.new.call }.to raise_error(/expected a list/)
    end
  end
end

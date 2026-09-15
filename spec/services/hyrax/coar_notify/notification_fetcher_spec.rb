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
end

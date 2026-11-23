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

  describe '#call recording endorsements and reviews on the work' do
    let(:inbox) { 'https://repository.example.org/coar_notify_inbox/notifications' }
    let(:work_class) { Struct.new(:id, :endorsements, :reviews, :has_endorsement, :has_review) }
    let(:work) { work_class.new('work-valkyrie-101', [], [], false, false) }
    let(:persister) { double('persister') }
    let(:index_adapter) { double('index adapter', save: nil) }

    def announcement(kind, provider: 'https://pci.example.org', url: 'https://pci.example.org/e/1')
      { 'id' => "urn:uuid:#{kind}-#{provider}-#{url}",
        'raw_payload' => { 'type' => ['Announce', "coar-notify:#{kind}Action"],
                           'origin' => { 'id' => provider },
                           'context' => { 'id' => 'https://repository.example.org/concern/datasets/work-valkyrie-101' },
                           'object' => { 'id' => url } } }
    end

    def serve(*notifications)
      stub_request(:get, inbox).to_return(status: 200, body: notifications.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    def fetch
      described_class.new.call
    end

    before do
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-valkyrie-101').and_return(work)
      allow(persister).to receive(:save) { |resource:| resource }
      allow(Hyrax).to receive(:persister).and_return(persister)
      allow(Hyrax).to receive(:index_adapter).and_return(index_adapter)
    end

    it 'records an endorsement, flags the work, then saves and indexes it' do
      serve(announcement('Endorsement'))
      fetch
      expect(work.endorsements.map { |e| JSON.parse(e) })
        .to eq([{ 'service_provider' => 'https://pci.example.org', 'endorsement_url' => 'https://pci.example.org/e/1' }])
      expect(work.has_endorsement).to be true
      expect(persister).to have_received(:save).once
      expect(index_adapter).to have_received(:save).once
    end

    it 'does not record the same endorsement again when the inbox serves it on a later run' do
      serve(announcement('Endorsement'))
      fetch
      fetch
      fetch
      expect(work.endorsements.size).to eq(1)
      expect(persister).to have_received(:save).once
      expect(index_adapter).to have_received(:save).once
    end

    it 'records it once when the same notification appears twice in one response' do
      serve(announcement('Endorsement'), announcement('Endorsement'))
      fetch
      expect(work.endorsements.size).to eq(1)
    end

    it 'records a different endorsement from the same provider' do
      serve(announcement('Endorsement', url: 'https://pci.example.org/e/1'), announcement('Endorsement', url: 'https://pci.example.org/e/2'))
      fetch
      expect(work.endorsements.size).to eq(2)
    end

    it 'records the same URL when it comes from a different provider' do
      serve(announcement('Endorsement', provider: 'https://a.example.org'), announcement('Endorsement', provider: 'https://b.example.org'))
      fetch
      expect(work.endorsements.size).to eq(2)
    end

    it 'recognises an entry already on the work however its JSON was written' do
      work.endorsements = ['{"endorsement_url": "https://pci.example.org/e/1", "service_provider": "https://pci.example.org"}']
      serve(announcement('Endorsement'))
      fetch
      expect(work.endorsements.size).to eq(1)
      expect(persister).not_to have_received(:save)
    end

    it 'ignores entries on the work that are not valid JSON, and still records the new one' do
      work.endorsements = ['not json']
      serve(announcement('Endorsement'))
      expect { fetch }.not_to raise_error
      expect(work.endorsements.size).to eq(2)
    end

    it 'does the same for reviews, leaving endorsements alone' do
      Hyrax::CoarNotify::NotifyRequest.create!(work_id: 'work-valkyrie-101', notify_service: service, request_type: 'request_review',
                                               status: 'sent')
      serve(announcement('Review', url: 'https://pci.example.org/r/1'))
      fetch
      fetch
      expect(work.reviews.map { |r| JSON.parse(r) })
        .to eq([{ 'service_provider' => 'https://pci.example.org', 'review_url' => 'https://pci.example.org/r/1' }])
      expect(work.has_review).to be true
      expect(work.endorsements).to eq([])
      expect(persister).to have_received(:save).once
    end
  end

  describe '#call with registered NotifyInbox records' do
    let(:configured_inbox) { 'https://repository.example.org/coar_notify_inbox/notifications' }

    def accept(id, action: 'coar-notify:EndorsementAction')
      { 'id' => id, 'raw_payload' => { 'type' => 'Accept',
                                       'object' => { 'type' => ['Offer', action],
                                                     'object' => { 'id' => 'https://repository.example.org/concern/datasets/work-valkyrie-101' } } } }
    end

    it 'ignores the configured inbox and fetches from an active registered inbox instead' do
      Hyrax::CoarNotify::NotifyInbox.create!(title: 'Repo inbox', inbox_url: 'https://registered.example.org/notifications',
                                             api_key: 'registered-token', status: true)
      configured_stub = stub_request(:get, configured_inbox)
      stub_request(:get, 'https://registered.example.org/notifications')
        .with(headers: { 'Authorization' => 'Bearer registered-token' })
        .to_return(status: 200, body: [accept('urn:uuid:reg-1')].to_json, headers: { 'Content-Type' => 'application/json' })

      described_class.new.call

      expect(notify_request.reload.status).to eq('Accepted')
      expect(configured_stub).not_to have_been_requested
    end

    it 'fetches from every active inbox, but not from an inactive one' do
      Hyrax::CoarNotify::NotifyInbox.create!(title: 'Active one', inbox_url: 'https://one.example.org/notifications', status: true)
      Hyrax::CoarNotify::NotifyInbox.create!(title: 'Active two', inbox_url: 'https://two.example.org/notifications', status: true)
      Hyrax::CoarNotify::NotifyInbox.create!(title: 'Inactive', inbox_url: 'https://three.example.org/notifications', status: false)
      stub_request(:get, 'https://one.example.org/notifications')
        .to_return(status: 200, body: [accept('urn:uuid:one')].to_json, headers: { 'Content-Type' => 'application/json' })
      review_request = Hyrax::CoarNotify::NotifyRequest.create!(work_id: 'work-valkyrie-101', notify_service: service,
                                                                request_type: 'request_review', status: 'sent')
      stub_request(:get, 'https://two.example.org/notifications')
        .to_return(status: 200, body: [{ 'id' => 'urn:uuid:two', 'raw_payload' => { 'type' => 'Reject',
                     'object' => { 'type' => ['Offer', 'coar-notify:ReviewAction'],
                                   'object' => { 'id' => 'https://repository.example.org/concern/datasets/work-valkyrie-101' } } } }].to_json,
                   headers: { 'Content-Type' => 'application/json' })
      inactive_stub = stub_request(:get, 'https://three.example.org/notifications')

      described_class.new.call

      expect(notify_request.reload.status).to eq('Accepted')
      expect(review_request.reload.status).to eq('Rejected')
      expect(inactive_stub).not_to have_been_requested
    end
  end

  describe '#call answering two requests for the same work' do
    let(:inbox) { 'https://repository.example.org/coar_notify_inbox/notifications' }
    let(:work_url) { 'https://repository.example.org/concern/datasets/work-valkyrie-101' }
    let!(:review_request) do
      Hyrax::CoarNotify::NotifyRequest.create!(work_id: 'work-valkyrie-101', notify_service: service, request_type: 'request_review',
                                               status: 'sent', notification_id: 'urn:uuid:review-1')
    end

    def accept(in_reply_to, action)
      { 'id' => "accept-#{in_reply_to}",
        'raw_payload' => { 'type' => 'Accept', 'inReplyTo' => in_reply_to,
                           'object' => { 'id' => in_reply_to, 'type' => ['Offer', action], 'object' => { 'id' => work_url } } } }
    end

    it 'updates each request from the reply that names it' do
      stub_request(:get, inbox).to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' },
        body: [accept('urn:uuid:review-1', 'coar-notify:ReviewAction'),
               accept('urn:uuid:notification-101', 'coar-notify:EndorsementAction').deep_merge('raw_payload' => { 'type' => 'Reject' })].to_json
      )
      described_class.new.call
      expect(review_request.reload.status).to eq('Accepted')
      expect(notify_request.reload.status).to eq('Rejected')
    end
  end
end

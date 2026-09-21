# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::NotifyRequestLogger do
  let(:service) { Hyrax::CoarNotify::NotifyService.create!(title: 'Peer Community', service_url: 'https://pci.org', status: true) }

  describe '.duplicate_request?' do
    it 'detects duplicate requests' do
      expect(described_class.duplicate_request?(work_id: 'work-abc', request_type: 'request_endorsement')).to be false

      Hyrax::CoarNotify::NotifyRequest.create!(
        work_id: 'work-abc',
        notify_service: service,
        request_type: 'request_endorsement',
        status: 'sent'
      )

      expect(described_class.duplicate_request?(work_id: 'work-abc', request_type: 'request_endorsement')).to be true
    end
  end

  describe '.extract_work_id' do
    it 'extracts work id from standard path' do
      expect(described_class.extract_work_id('http://example.org/concern/datasets/12345')).to eq('12345')
      expect(described_class.extract_work_id('plain-work-id')).to eq('plain-work-id')
    end
  end

  describe '.notification_status' do
    def status_for(type)
      described_class.notification_status('raw_payload' => { 'type' => type })
    end

    it 'maps the reply types, including a plain Accept' do
      expect(status_for('Accept')).to eq('accept')
      expect(status_for('Reject')).to eq('reject')
      expect(status_for('TentativeAccept')).to eq('tentative_accept')
      expect(status_for('TentativeReject')).to eq('tentative_reject')
    end

    it 'maps announcements by their action type' do
      expect(status_for(['Announce', 'coar-notify:EndorsementAction'])).to eq('announce_endorsement')
      expect(status_for(['Announce', 'coar-notify:ReviewAction'])).to eq('announce_review')
    end

    it 'does not treat other announcements (such as a relationship) as a review' do
      expect(status_for(['Announce', 'coar-notify:RelationshipAction'])).to be_nil
    end

    it 'returns nil for unknown, blank or missing types' do
      expect(status_for('Offer')).to be_nil
      expect(status_for('Sent')).to be_nil
      expect(status_for('')).to be_nil
      expect(status_for(nil)).to be_nil
      expect(described_class.notification_status({})).to be_nil
    end
  end

  describe '.create_or_update_requests_for_notification' do
    let!(:request) do
      Hyrax::CoarNotify::NotifyRequest.create!(work_id: 'work-1', notify_service: service, request_type: 'request_endorsement',
                                               status: 'sent')
    end

    def notification(type)
      { 'id' => 'n-1', 'raw_payload' => { 'type' => type,
                                          'object' => { 'object' => { 'id' => 'https://repo.test/concern/datasets/work-1' } } } }
    end

    it 'moves the request to Accepted when the service accepts it' do
      expect(described_class.create_or_update_requests_for_notification(notification('Accept'))).to eq(request)
      expect(request.reload.status).to eq('Accepted')
    end

    it 'updates the request for the other reply types' do
      described_class.create_or_update_requests_for_notification(notification('Reject'))
      expect(request.reload.status).to eq('Rejected')
    end

    it 'ignores, and logs, a notification of an unsupported type without touching the request' do
      allow(Rails.logger).to receive(:warn)
      expect(described_class.create_or_update_requests_for_notification(notification('Offer'))).to be_nil
      expect(request.reload.status).to eq('Sent')
      expect(Rails.logger).to have_received(:warn).with(/ignoring notification n-1 of unsupported type "Offer"/)
    end
  end
end

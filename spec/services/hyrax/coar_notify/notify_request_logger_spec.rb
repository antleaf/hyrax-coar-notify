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

  describe 'matching a notification to the right request' do
    let(:work_url) { 'https://repo.test/concern/datasets/work-1' }

    def make_request(type, id: nil, status: 'sent', work: 'work-1')
      Hyrax::CoarNotify::NotifyRequest.create!(work_id: work, notify_service: service, request_type: type, status: status,
                                               notification_id: id)
    end

    def apply(payload)
      described_class.create_or_update_requests_for_notification('id' => 'n-1', 'raw_payload' => payload)
    end

    def reply(type, in_reply_to: nil, action: nil, object_id: in_reply_to)
      payload = { 'type' => type,
                  'object' => { 'id' => object_id, 'type' => ['Offer', action].compact,
                                'object' => { 'id' => work_url } } }
      payload['inReplyTo'] = in_reply_to if in_reply_to
      payload
    end

    def announcement(action, in_reply_to: nil)
      payload = { 'type' => ['Announce', "coar-notify:#{action}"], 'context' => { 'id' => work_url },
                  'object' => { 'id' => 'https://pci.test/x' } }
      payload['inReplyTo'] = in_reply_to if in_reply_to
      payload
    end

    context 'when a work has both an endorsement and a review request pending' do
      # Created review-first, so the old find_by(work_id:) would have picked the review row.
      let!(:review) { make_request('request_review', id: 'urn:uuid:review-1') }
      let!(:endorsement) { make_request('request_endorsement', id: 'urn:uuid:endorse-1') }

      it 'updates the request a reply names, whichever kind that is' do
        apply(reply('Accept', in_reply_to: 'urn:uuid:review-1', action: 'coar-notify:ReviewAction'))
        expect(review.reload.status).to eq('Accepted')
        expect(endorsement.reload.status).to eq('Sent')

        apply(reply('Reject', in_reply_to: 'urn:uuid:endorse-1', action: 'coar-notify:EndorsementAction'))
        expect(endorsement.reload.status).to eq('Rejected')
        expect(review.reload.status).to eq('Accepted')
      end

      it 'updates only the review for an announced review' do
        apply(announcement('ReviewAction', in_reply_to: 'urn:uuid:review-1'))
        expect(review.reload.status).to eq('Announced Review')
        expect(endorsement.reload.status).to eq('Sent')
      end

      it 'updates only the endorsement for an announced endorsement that names no request' do
        apply(announcement('EndorsementAction'))
        expect(endorsement.reload.status).to eq('Announced Endorsement')
        expect(review.reload.status).to eq('Sent')
      end

      it 'uses the kind repeated in a reply when it names no request' do
        apply(reply('TentativeAccept', action: 'coar-notify:ReviewAction'))
        expect(review.reload.status).to eq('Tentatively Accepted')
        expect(endorsement.reload.status).to eq('Sent')
      end

      it 'falls back to work and kind when the id it replies to is not one of ours' do
        apply(announcement('EndorsementAction', in_reply_to: 'urn:uuid:someone-elses'))
        expect(endorsement.reload.status).to eq('Announced Endorsement')
        expect(review.reload.status).to eq('Sent')
      end

      it 'does not let an id from the other kind of request win' do
        apply(announcement('ReviewAction', in_reply_to: 'urn:uuid:endorse-1'))
        expect(review.reload.status).to eq('Announced Review')
        expect(endorsement.reload.status).to eq('Sent')
      end
    end

    it 'picks the exact request named, even when a newer one exists for the same work' do
      older = make_request('request_endorsement', id: 'urn:uuid:old')
      newer = make_request('request_endorsement', id: 'urn:uuid:new')
      apply(reply('Reject', in_reply_to: 'urn:uuid:old', action: 'coar-notify:EndorsementAction'))
      expect(older.reload.status).to eq('Rejected')
      expect(newer.reload.status).to eq('Sent')
    end

    it 'prefers the newest request still waiting for an answer when the reply says nothing else' do
      waiting = make_request('request_endorsement', id: 'urn:uuid:a')
      answered = make_request('request_review', id: 'urn:uuid:b', status: 'reject')
      apply(reply('Accept'))
      expect(waiting.reload.status).to eq('Accepted')
      expect(answered.reload.status).to eq('Rejected')
    end

    it 'still updates the newest request when none is waiting' do
      make_request('request_endorsement', id: 'urn:uuid:a', status: 'reject')
      newest = make_request('request_review', id: 'urn:uuid:b', status: 'reject')
      apply(reply('Accept'))
      expect(newest.reload.status).to eq('Accepted')
    end

    it 'matches requests sent before ids were unique (blank id, or one id shared by both kinds)' do
      endorsement = make_request('request_endorsement', id: 'urn:uuid:work-1')
      review = make_request('request_review', id: nil)
      apply(announcement('ReviewAction', in_reply_to: 'urn:uuid:work-1'))
      expect(review.reload.status).to eq('Announced Review')
      expect(endorsement.reload.status).to eq('Sent')
    end

    it 'ignores, and logs, an announcement when no request of that kind exists for the work' do
      endorsement = make_request('request_endorsement', id: 'urn:uuid:endorse-1')
      allow(Rails.logger).to receive(:info)
      expect(apply(announcement('ReviewAction'))).to be_nil
      expect(endorsement.reload.status).to eq('Sent')
      expect(Rails.logger).to have_received(:info).with(/no request matches notification n-1/)
    end

    it 'ignores a reply for a work we never sent a request for' do
      expect(apply(reply('Accept', in_reply_to: 'urn:uuid:unknown'))).to be_nil
    end
  end
end

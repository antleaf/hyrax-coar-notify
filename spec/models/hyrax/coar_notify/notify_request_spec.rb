# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::NotifyRequest, type: :model do
  let(:notify_service) { Hyrax::CoarNotify::NotifyService.create!(title: 'Service A', service_url: 'https://service.org', status: true) }

  describe 'validations and associations' do
    it 'validates presence of work_id, request_type, and status' do
      request = described_class.new(notify_service: notify_service)
      expect(request).not_to be_valid
      expect(request.errors[:work_id]).to include("can't be blank")
    end

    it 'persists successfully with valid attributes' do
      request = described_class.create!(
        work_id: 'work-123',
        notify_service: notify_service,
        request_type: 'request_endorsement',
        status: 'sent',
        notification_id: 'urn:uuid:12345'
      )

      expect(request).to be_persisted
      expect(described_class.with_notifications).to include(request)
    end
  end
end

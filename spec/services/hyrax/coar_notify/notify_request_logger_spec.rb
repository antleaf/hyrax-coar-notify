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
end

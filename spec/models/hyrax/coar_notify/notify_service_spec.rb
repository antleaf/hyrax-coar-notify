# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::NotifyService, type: :model do
  describe 'scopes and methods' do
    let!(:active_service) { described_class.create!(title: 'Active Service', service_url: 'https://service.org', status: true) }
    let!(:inactive_service) { described_class.create!(title: 'Inactive Service', service_url: 'https://inactive.org', status: false) }

    it 'returns active and inactive services' do
      expect(described_class.active).to include(active_service)
      expect(described_class.active).not_to include(inactive_service)
      expect(described_class.inactive).to include(inactive_service)
    end

    it 'evaluates active?' do
      expect(active_service.active?).to be true
      expect(inactive_service.active?).to be false
    end
  end
end

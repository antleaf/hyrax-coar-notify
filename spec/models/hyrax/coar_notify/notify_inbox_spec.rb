# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::NotifyInbox, type: :model do
  describe 'scopes and methods' do
    let!(:active_inbox) { described_class.create!(title: 'Active Inbox', service_url: 'https://inbox.org', status: true) }
    let!(:inactive_inbox) { described_class.create!(title: 'Inactive Inbox', service_url: 'https://inactive-inbox.org', status: false) }

    it 'returns active and inactive inboxes' do
      expect(described_class.active).to include(active_inbox)
      expect(described_class.active).not_to include(inactive_inbox)
      expect(described_class.inactive).to include(inactive_inbox)
    end

    it 'evaluates active?' do
      expect(active_inbox.active?).to be true
      expect(inactive_inbox.active?).to be false
    end
  end
end

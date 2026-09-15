# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify do
  describe '.configuration' do
    it 'allows configuring base_url and admin_api_token' do
      Hyrax::CoarNotify.configure do |config|
        config.base_url = 'https://notify.example.org'
        config.admin_api_token = 'secret_test_token'
      end

      expect(Hyrax::CoarNotify.config.base_url).to eq('https://notify.example.org')
      expect(Hyrax::CoarNotify.config.admin_api_token).to eq('secret_test_token')
    end
  end
end

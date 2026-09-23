# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::Engine do
  it 'auto-includes WorkShowPresenterBehavior into Hyrax::WorkShowPresenter' do
    expect(Hyrax::WorkShowPresenter.ancestors).to include(Hyrax::CoarNotify::WorkShowPresenterBehavior)
  end
end

# frozen_string_literal: true

require 'rails_helper'
require 'generators/hyrax/coar_notify/install_generator'

RSpec.describe Hyrax::CoarNotify::InstallGenerator, type: :generator do
  it 'has a defined source root' do
    expect(described_class.source_root).to be_present
    expect(File.directory?(described_class.source_root)).to be true
  end
end

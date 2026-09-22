# frozen_string_literal: true

require 'rails_helper'

# Bundler.require, with no `require:` given in the Gemfile, does `Kernel.require dep.name` -
# i.e. `require "hyrax-coar-notify"` literally - before ever trying anything else. This proves that
# exact call resolves, the same way it would in a host that just wrote `gem "hyrax-coar-notify"`.
RSpec.describe 'Bundler autorequire compatibility' do
  it 'loads via the literal gem name' do
    lib_dir = File.expand_path('../../../lib', __dir__)
    $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

    expect { require 'hyrax-coar-notify' }.not_to raise_error
    expect(defined?(Hyrax::CoarNotify)).to be_truthy
  end
end

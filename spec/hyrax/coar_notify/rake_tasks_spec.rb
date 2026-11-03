# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'Hyrax::CoarNotify rake tasks' do
  before do
    Rake::Task.clear
    Dir[Hyrax::CoarNotify::Engine.root.join('lib', 'tasks', '**', '*.rake')].each { |file| load file }
  end

  after { Rake::Task.clear }

  it 'ships the host-setup tasks' do
    expect(Rake::Task.task_defined?('notify:setup_hyrax')).to be true
    expect(Rake::Task.task_defined?('notify:setup_default_roles')).to be true
    expect(Rake::Task.task_defined?('db:exists')).to be true
  end
end

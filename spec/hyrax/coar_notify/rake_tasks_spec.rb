# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'Hyrax::CoarNotify rake tasks' do
  before do
    Rake::Task.clear
    Dir[Hyrax::CoarNotify::Engine.root.join('lib', 'tasks', '**', '*.rake')].each { |file| load file }
  end

  after { Rake::Task.clear }

  it 'does not ship app-scaffolding tasks that duplicate a host app own copies' do
    expect(Rake::Task.task_defined?('notify:setup_hyrax')).to be false
    expect(Rake::Task.task_defined?('notify:setup_default_roles')).to be false
    expect(Rake::Task.task_defined?('db:exists')).to be false
  end
end

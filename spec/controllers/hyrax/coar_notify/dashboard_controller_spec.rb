# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/manager_only_examples'

RSpec.describe Hyrax::CoarNotify::DashboardController, type: :controller do
  routes { Hyrax::CoarNotify::Engine.routes }

  it_behaves_like 'manager-only actions',
                  'GET index' => -> { get :index },
                  'GET manage_connections' => -> { get :manage_connections }
end

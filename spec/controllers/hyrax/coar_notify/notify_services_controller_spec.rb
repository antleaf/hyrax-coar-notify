# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/manager_only_examples'

RSpec.describe Hyrax::CoarNotify::NotifyServicesController, type: :controller do
  routes { Hyrax::CoarNotify::Engine.routes }

  let!(:service) do
    Hyrax::CoarNotify::NotifyService.create!(title: 'PCI', service_url: 'http://pci.test', inbox_url: 'http://pci.test/inbox',
                                             api_key: 'secret-key', status: true)
  end
  let(:new_attrs) { { title: 'New', service_url: 'http://new.test', inbox_url: 'http://new.test/inbox', api_key: 'k', status: true } }

  before { allow(Hyrax::CoarNotify::NotifyAPIClient).to receive(:sync_notify_service) }

  it_behaves_like 'manager-only actions',
                  'GET index' => -> { get :index },
                  'GET new' => -> { get :new },
                  'GET edit' => -> { get :edit, params: { id: service.id } },
                  'POST create' => -> { post :create, params: { notify_service: new_attrs } },
                  'PATCH update' => -> { patch :update, params: { id: service.id, notify_service: { title: 'Changed' } } },
                  'DELETE destroy' => -> { delete :destroy, params: { id: service.id } }

  context 'when access is refused' do
    let(:plain) { User.create!(email: 'plain@example.com') }

    before { allow(controller).to receive(:current_user).and_return(plain) }

    it 'does not create a service' do
      expect { post :create, params: { notify_service: new_attrs } }.not_to change(Hyrax::CoarNotify::NotifyService, :count)
    end

    it 'does not change a service' do
      patch :update, params: { id: service.id, notify_service: { title: 'Changed' } }
      expect(service.reload.title).to eq('PCI')
    end

    it 'does not delete a service' do
      expect { delete :destroy, params: { id: service.id } }.not_to change(Hyrax::CoarNotify::NotifyService, :count)
    end

    it 'never reveals the API key' do
      get :edit, params: { id: service.id }
      expect(response.body).not_to include('secret-key')
    end
  end

  describe 'request endpoints' do
    it 'send an anonymous visitor to sign in without queueing anything' do
      expect { post :request_endorsement, params: { id: service.id, work_id: 'w1' } }
        .not_to have_enqueued_job
      expect(response).to redirect_to('http://test.host/users/sign_in')
    end
  end
end

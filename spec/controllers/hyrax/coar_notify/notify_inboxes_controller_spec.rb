# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/manager_only_examples'

RSpec.describe Hyrax::CoarNotify::NotifyInboxesController, type: :controller do
  routes { Hyrax::CoarNotify::Engine.routes }

  let!(:inbox) do
    Hyrax::CoarNotify::NotifyInbox.create!(title: 'Inbox', service_url: 'http://inbox.test', inbox_url: 'http://inbox.test/n',
                                           api_key: 'inbox-secret', status: true)
  end
  let(:new_attrs) { { title: 'New', service_url: 'http://new.test', inbox_url: 'http://new.test/n', api_key: 'k', status: true } }

  it_behaves_like 'manager-only actions',
                  'GET index' => -> { get :index },
                  'GET new' => -> { get :new },
                  'GET edit' => -> { get :edit, params: { id: inbox.id } },
                  'POST create' => -> { post :create, params: { notify_inbox: new_attrs } },
                  'PATCH update' => -> { patch :update, params: { id: inbox.id, notify_inbox: { title: 'Changed' } } },
                  'DELETE destroy' => -> { delete :destroy, params: { id: inbox.id } }

  context 'when access is refused' do
    let(:plain) { User.create!(email: 'plain@example.com') }

    before { allow(controller).to receive(:current_user).and_return(plain) }

    it 'does not create, change or delete an inbox' do
      expect { post :create, params: { notify_inbox: new_attrs } }.not_to change(Hyrax::CoarNotify::NotifyInbox, :count)
      patch :update, params: { id: inbox.id, notify_inbox: { title: 'Changed' } }
      expect(inbox.reload.title).to eq('Inbox')
      expect { delete :destroy, params: { id: inbox.id } }.not_to change(Hyrax::CoarNotify::NotifyInbox, :count)
    end

    it 'never reveals the API key' do
      get :edit, params: { id: inbox.id }
      expect(response.body).not_to include('inbox-secret')
    end
  end
end

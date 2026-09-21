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
    let(:user) { User.create!(email: 'depositor@example.com') }
    let(:sign_in_url) { 'http://test.host/users/sign_in' }
    let(:root_url) { 'http://test.host/' }
    let(:refusal) { 'You are not authorized to request an endorsement or review for this work.' }

    # An ability that lets the user edit exactly one work, like a depositor's.
    let(:editor_ability) do
      Object.new.extend(CanCan::Ability).tap { |a| a.can(:edit, String) { |id| id == 'my-work' } }
    end

    {
      request_endorsement: Hyrax::CoarNotify::RequestEndorsementJob,
      request_review: Hyrax::CoarNotify::RequestReviewJob
    }.each do |action, job|
      describe action.to_s do
        def request_for(action, work_id)
          post action, params: { id: service.id, work_id: work_id }
        end

        it 'sends an anonymous visitor to sign in without queueing anything' do
          expect { request_for(action, 'my-work') }.not_to have_enqueued_job
          expect(response).to redirect_to(sign_in_url)
        end

        context 'when signed in' do
          before { allow(controller).to receive(:current_user).and_return(user) }

          it 'refuses a user who cannot edit the work, without queueing anything' do
            allow(controller).to receive(:current_ability).and_return(editor_ability)
            expect { request_for(action, 'someone-elses-work') }.not_to have_enqueued_job
            expect(response).to redirect_to(root_url)
            expect(flash[:alert]).to eq(refusal)
          end

          it 'refuses a user with no abilities at all' do
            expect { request_for(action, 'my-work') }.not_to have_enqueued_job
            expect(flash[:alert]).to eq(refusal)
          end

          it 'refuses a request with no work id' do
            allow(controller).to receive(:current_ability).and_return(editor_ability)
            expect { request_for(action, nil) }.not_to have_enqueued_job
            expect(flash[:alert]).to eq(refusal)
          end

          it 'refuses, rather than erroring, when the ability has no permissions document for the work id' do
            ability = Object.new.extend(CanCan::Ability)
            allow(ability).to receive(:can?).and_raise(Blacklight::Exceptions::RecordNotFound)
            allow(controller).to receive(:current_ability).and_return(ability)
            expect { request_for(action, 'no-such-work') }.not_to have_enqueued_job
            expect(response).to redirect_to(root_url)
            expect(flash[:alert]).to eq(refusal)
          end

          it 'does not reveal an existing request to a user who cannot edit the work' do
            Hyrax::CoarNotify::NotifyRequest.create!(work_id: 'someone-elses-work', notify_service: service,
                                                     request_type: action.to_s, status: 'sent')
            allow(controller).to receive(:current_ability).and_return(editor_ability)
            request_for(action, 'someone-elses-work')
            expect(flash[:alert]).to eq(refusal)
          end

          it 'queues the job for a user who can edit the work' do
            allow(controller).to receive(:current_ability).and_return(editor_ability)
            expect { request_for(action, 'my-work') }
              .to have_enqueued_job(job).with(work_id: 'my-work', service_id: service.id, user_id: user.id)
            expect(flash[:alert]).to be_nil
            expect(flash[:notice]).to be_present
          end

          it 'still rejects a duplicate request from an editor' do
            Hyrax::CoarNotify::NotifyRequest.create!(work_id: 'my-work', notify_service: service,
                                                     request_type: action.to_s, status: 'sent')
            allow(controller).to receive(:current_ability).and_return(editor_ability)
            expect { request_for(action, 'my-work') }.not_to have_enqueued_job
            expect(flash[:alert]).to include('already been submitted')
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

# Shared examples for controllers guarded by ApplicationController#authorize_manager!.
# Pass a hash of description => lambda; each lambda performs one request (it runs inside the example,
# so it can use `let` values).
RSpec.shared_examples 'manager-only actions' do |actions|
  let(:sign_in_url) { 'http://test.host/users/sign_in' }
  let(:root_url) { 'http://test.host/' }
  let(:admin)   { User.create!(email: 'admin@example.com', admin: true) }
  let(:plain)   { User.create!(email: 'plain@example.com') }
  let(:manager) { User.create!(email: 'manager@example.com').tap { |u| u.groups = ['notify_manager'] } }

  def sign_in(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  def expect_refused
    expect(response).to redirect_to(root_url)
    expect(flash[:alert]).to eq('You are not authorized to manage Notify connections.')
  end

  def expect_allowed
    expect(flash[:alert]).to be_nil
    expect(response).not_to redirect_to(sign_in_url)
    expect(response).not_to redirect_to(root_url)
  end

  after { Hyrax::CoarNotify.reset_configuration! }

  actions.each do |name, request|
    describe name do
      it 'sends an anonymous visitor to sign in' do
        instance_exec(&request)
        expect(response).to redirect_to(sign_in_url)
      end

      it 'refuses a signed-in user without access' do
        sign_in(plain)
        instance_exec(&request)
        expect_refused
      end

      it 'refuses a user whose role is not the manager role' do
        Hyrax::CoarNotify.config.manager_role = 'notify_manager'
        sign_in(User.create!(email: 'other@example.com').tap { |u| u.groups = ['reviewer'] })
        instance_exec(&request)
        expect_refused
      end

      it 'refuses everyone when no manager role is configured and there is no other grant' do
        Hyrax::CoarNotify.config.manager_role = nil
        sign_in(manager)
        instance_exec(&request)
        expect_refused
      end

      it 'allows an admin' do
        sign_in(admin)
        instance_exec(&request)
        expect_allowed
      end

      it 'allows an admin even when a different manager role is configured' do
        Hyrax::CoarNotify.config.manager_role = 'notify_manager'
        sign_in(admin)
        instance_exec(&request)
        expect_allowed
      end

      it 'allows a user the ability reports as admin' do
        sign_in(plain)
        allow(controller).to receive(:current_ability).and_return(double(admin?: true, can?: false))
        instance_exec(&request)
        expect_allowed
      end

      it 'allows a user holding the configured manager role' do
        Hyrax::CoarNotify.config.manager_role = 'notify_manager'
        sign_in(manager)
        instance_exec(&request)
        expect_allowed
      end

      it 'allows a user the host Ability grants :access, :coar_notify' do
        sign_in(plain)
        ability = Object.new.extend(CanCan::Ability).tap { |a| a.can :access, :coar_notify }
        allow(controller).to receive(:current_ability).and_return(ability)
        instance_exec(&request)
        expect_allowed
      end
    end
  end
end

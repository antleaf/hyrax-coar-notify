# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/coar_notify/dashboard/index', type: :view do
  let(:service) do
    Hyrax::CoarNotify::NotifyService.create!(title: 'PCI', service_url: 'http://pci.test', inbox_url: 'http://pci.test/inbox',
                                             api_key: 'k', status: true)
  end
  let(:user) { User.create!(email: 'author@example.org', password: 'password123') }

  # The view uses the engine's own route helper, which a view spec doesn't mount.
  before { view.define_singleton_method(:manage_notify_connections_path) { '/coar_notify/manage_connections' } }

  def request_for(work_id, updated_at:)
    Hyrax::CoarNotify::NotifyRequest.create!(work_id: work_id, notify_service: service, user: user,
                                             request_type: 'request_endorsement', status: 'sent',
                                             notification_id: "urn:uuid:#{SecureRandom.uuid}").tap do |r|
      r.update_column(:updated_at, updated_at)
    end
  end

  def render_dashboard(notifications, work_paths)
    assign(:notifications, notifications)
    assign(:work_paths, work_paths)
    render template: 'hyrax/coar_notify/dashboard/index'
  end

  it 'has a Last modified column showing when each request last changed' do
    notification = request_for('w1', updated_at: Time.zone.local(2026, 11, 20, 14, 5))
    render_dashboard([notification], {})

    expect(rendered).to have_css('th', text: 'Last modified')
    expect(rendered).to have_css('td', text: I18n.l(notification.reload.updated_at, format: :short))
  end

  it 'links the work id to the work when the work is known' do
    render_dashboard([request_for('w1', updated_at: 1.day.ago)], 'w1' => '/concern/datasets/w1')
    expect(rendered).to have_link('w1', href: '/concern/datasets/w1')
  end

  it 'shows only the plain id, without raising, when the work no longer exists' do
    render_dashboard([request_for('gone', updated_at: 1.day.ago)], {})
    expect(rendered).to have_css('td', text: 'gone')
    expect(rendered).not_to have_link('gone')
  end

  it 'links known works and leaves unknown ones as text in the same table' do
    render_dashboard([request_for('w1', updated_at: 1.hour.ago), request_for('gone', updated_at: 2.hours.ago)],
                     'w1' => '/concern/datasets/w1')
    expect(rendered).to have_link('w1')
    expect(rendered).not_to have_link('gone')
  end

  it 'spans all seven columns in the empty-state row' do
    render_dashboard(Hyrax::CoarNotify::NotifyRequest.none, {})
    expect(rendered).to have_css('td[colspan="7"]', text: 'No messages found')
  end
end

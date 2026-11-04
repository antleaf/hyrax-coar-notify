# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/coar_notify/shared/_endorsement_actions', type: :view do
  let!(:service) do
    Hyrax::CoarNotify::NotifyService.create!(title: 'PCI', service_url: 'http://pci.test', inbox_url: 'http://pci.test/inbox',
                                             api_key: 'k', status: true)
  end

  let(:presenter_class) do
    Class.new do
      include Hyrax::CoarNotify::WorkShowPresenterBehavior

      attr_reader :id, :editor

      def initialize(id:, editor:)
        @id = id
        @editor = editor
      end

      def editor? = editor
    end
  end

  def render_for(presenter)
    render partial: 'hyrax/coar_notify/shared/endorsement_actions', locals: { presenter: presenter }
  end

  it 'shows both request menus, listing the service, to someone who can edit the work' do
    render_for(presenter_class.new(id: 'my-work', editor: true))
    expect(rendered).to include('RequestEndorsementButton', 'RequestReviewButton', 'PCI')
    expect(rendered).to include("notify_services/#{service.id}/request_endorsement")
    expect(rendered).to include('work_id=my-work')
  end

  it 'shows nothing to someone who cannot edit the work' do
    render_for(presenter_class.new(id: 'my-work', editor: false))
    expect(rendered.strip).to be_empty
  end

  it 'shows nothing when the presenter cannot say who may edit' do
    bare = Class.new { include Hyrax::CoarNotify::WorkShowPresenterBehavior; def id = 'my-work' }.new
    render_for(bare)
    expect(rendered.strip).to be_empty
  end

  it 'shows nothing to an editor when no service is active' do
    service.update!(status: false)
    render_for(presenter_class.new(id: 'my-work', editor: true))
    expect(rendered.strip).to be_empty
  end
end

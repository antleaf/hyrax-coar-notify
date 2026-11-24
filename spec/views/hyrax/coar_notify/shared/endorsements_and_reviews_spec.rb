# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/coar_notify/shared/_endorsements_and_reviews', type: :view do
  def presenter(endorsements: [], reviews: [])
    double('Presenter', parsed_endorsements: endorsements, parsed_reviews: reviews)
  end

  def render_for(presenter)
    render partial: 'hyrax/coar_notify/shared/endorsements_and_reviews', locals: { presenter: presenter }
  end

  let(:endorsement) { { 'service_provider' => 'PCI', 'endorsement_url' => 'https://pci.example.org/e/1' } }
  let(:review)      { { 'service_provider' => 'PCI', 'review_url' => 'https://pci.example.org/r/1' } }

  it 'shows the endorsement and review URLs as links that open safely in a new tab' do
    render_for(presenter(endorsements: [endorsement], reviews: [review]))

    expect(rendered).to have_link('https://pci.example.org/e/1', href: 'https://pci.example.org/e/1')
    expect(rendered).to have_link('https://pci.example.org/r/1', href: 'https://pci.example.org/r/1')
    expect(rendered).to have_css('a[target="_blank"][rel~="noopener"][rel~="noreferrer"]', count: 2)
  end

  it 'accepts symbol-keyed hashes as well' do
    render_for(presenter(endorsements: [{ service_provider: 'PCI', endorsement_url: 'http://pci.example.org/e/2' }]))
    expect(rendered).to have_link('http://pci.example.org/e/2', href: 'http://pci.example.org/e/2')
  end

  it 'renders a JSON-string entry the same as a hash' do
    render_for(presenter(endorsements: [endorsement.to_json], reviews: [review.to_json]))
    expect(rendered).to have_link('https://pci.example.org/e/1')
    expect(rendered).to have_link('https://pci.example.org/r/1')
  end

  it 'shows the service provider' do
    render_for(presenter(endorsements: [endorsement]))
    expect(rendered).to have_css('p', text: 'Service Provider: PCI')
  end

  %w[javascript:alert(1) JAVASCRIPT:alert(1) data:text/html,<b>x</b> vbscript:x ftp://pci.example.org/e not-a-url //pci.example.org/e https:///nohost].each do |bad|
    it "does not make #{bad.inspect} clickable, and escapes it" do
      render_for(presenter(endorsements: [endorsement.merge('endorsement_url' => bad)],
                           reviews: [review.merge('review_url' => bad)]))
      expect(rendered).not_to have_css('a[href]')
      expect(rendered).not_to include('<b>x</b>')
    end
  end

  it 'links a URL that has stray whitespace around it, using the trimmed address' do
    render_for(presenter(endorsements: [endorsement.merge('endorsement_url' => ' https://pci.example.org/e/1 ')]))
    expect(rendered).to have_link(href: 'https://pci.example.org/e/1')
  end

  it 'skips the URL line when there is no URL' do
    render_for(presenter(endorsements: [{ 'service_provider' => 'PCI' }]))
    expect(rendered).not_to include('Endorsement URL')
  end

  it 'does not raise on entries that are not a hash (unparseable string, JSON array, number)' do
    expect { render_for(presenter(endorsements: ['not json', '[1,2]', '42', nil], reviews: [7])) }.not_to raise_error
  end

  it 'renders nothing when there are no endorsements or reviews' do
    render_for(presenter)
    expect(rendered.strip).to be_empty
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CoarNotify::WorkPathResolver do
  def hit(id, model)
    { 'id' => id, 'has_model_ssim' => [model] }
  end

  it 'maps each work id to its show path, using one Solr query for all of them' do
    expect(Hyrax::SolrService).to receive(:query).once
      .with('{!terms f=id}w1,w2', fl: 'id,has_model_ssim', rows: 2, method: :post)
      .and_return([hit('w1', 'Dataset'), hit('w2', 'GenericWork')])

    expect(described_class.call(%w[w1 w2])).to eq('w1' => '/concern/datasets/w1', 'w2' => '/concern/generic_works/w2')
  end

  it 'routes a Valkyrie "...Resource" model by the name of its work type' do
    allow(Hyrax::SolrService).to receive(:query).and_return([hit('w1', 'DatasetResource')])
    expect(described_class.call(['w1'])).to eq('w1' => '/concern/datasets/w1')
  end

  it 'prefixes the app base path, so a relative URL root is respected' do
    allow(Hyrax::SolrService).to receive(:query).and_return([hit('w1', 'Dataset')])
    expect(described_class.call(['w1'], base_path: '/repo/')).to eq('w1' => '/repo/concern/datasets/w1')
  end

  it 'ignores a query string on the base path, such as the locale root_path carries' do
    allow(Hyrax::SolrService).to receive(:query).and_return([hit('w1', 'Dataset')])
    expect(described_class.call(['w1'], base_path: '/?locale=en')).to eq('w1' => '/concern/datasets/w1')
    expect(described_class.call(['w1'], base_path: '/repo/?locale=en')).to eq('w1' => '/repo/concern/datasets/w1')
  end

  it 'leaves out works Solr does not know about (for example deleted ones)' do
    allow(Hyrax::SolrService).to receive(:query).and_return([hit('w1', 'Dataset')])
    expect(described_class.call(%w[w1 gone])).to eq('w1' => '/concern/datasets/w1')
  end

  it 'leaves out a work whose model is missing or not a plausible route segment' do
    allow(Hyrax::SolrService).to receive(:query)
      .and_return([{ 'id' => 'w1' }, hit('w2', '../admin'), hit('w3', 'Dataset')])
    expect(described_class.call(%w[w1 w2 w3])).to eq('w3' => '/concern/datasets/w3')
  end

  it 'looks each distinct id up once and ignores blanks' do
    expect(Hyrax::SolrService).to receive(:query)
      .with('{!terms f=id}w1', fl: 'id,has_model_ssim', rows: 1, method: :post).and_return([])
    described_class.call(['w1', 'w1', '', nil])
  end

  it 'does not query Solr at all when there are no ids' do
    expect(Hyrax::SolrService).not_to receive(:query)
    expect(described_class.call([])).to eq({})
  end

  it 'returns no links, and does not raise, when Solr is unreachable' do
    allow(Hyrax::SolrService).to receive(:query).and_raise(RSolr::Error::ConnectionRefused)
    expect(described_class.call(['w1'])).to eq({})
  end
end

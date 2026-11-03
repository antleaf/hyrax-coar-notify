# frozen_string_literal: true

require 'rails_helper'
require 'generators/hyrax/coar_notify/install_generator'
require 'tmpdir'
require 'fileutils'

RSpec.describe Hyrax::CoarNotify::InstallGenerator, type: :generator do
  it 'has a defined source root' do
    expect(described_class.source_root).to be_present
    expect(File.directory?(described_class.source_root)).to be true
  end

  describe '#inject_sidebar_link' do
    let(:sidebar_path) { 'app/views/hyrax/dashboard/_sidebar.html.erb' }
    let(:sidebar_contents) do
      <<~ERB
        <nav aria-label="sidebar-nav">
          <ul class="nav nav-pills flex-column">
            <li class="nav-item">existing item</li>
          </ul>
        </nav>
      ERB
    end

    # bin/rails generate always runs with the process cwd at the host app root, which is what the
    # generator's plain File.exist?/File.read calls (and Thor's own destination_root default) rely on.
    def in_host_app(with_sidebar: true)
      Dir.mktmpdir do |dir|
        if with_sidebar
          FileUtils.mkdir_p(File.join(dir, File.dirname(sidebar_path)))
          File.write(File.join(dir, sidebar_path), sidebar_contents)
        end
        Dir.chdir(dir) { yield }
      end
    end

    it 'inserts the link inside the <ul>, not after the closing </nav>' do
      in_host_app do
        described_class.new.inject_sidebar_link
        result = File.read(sidebar_path)

        expect(result).to include('coar_notify')
        expect(result.index('coar_notify')).to be < result.index('</ul>')
        expect(result.index('</ul>')).to be < result.index('</nav>')
      end
    end

    it 'only shows the link to users who can access Notify' do
      in_host_app do
        described_class.new.inject_sidebar_link
        result = File.read(sidebar_path)

        expect(result.index("can?(:access, :coar_notify)")).to be < result.index('hyrax_coar_notify.root_path')
        expect(result).to include('hyrax_coar_notify.root_path')
      end
    end

    it 'does not insert a second link on a repeat run' do
      in_host_app do
        described_class.new.inject_sidebar_link
        once = File.read(sidebar_path)

        described_class.new.inject_sidebar_link
        twice = File.read(sidebar_path)

        expect(twice).to eq(once)
      end
    end

    it 'does nothing when the host has no sidebar partial to customize' do
      in_host_app(with_sidebar: false) do
        expect { described_class.new.inject_sidebar_link }.not_to raise_error
        expect(File.exist?(sidebar_path)).to be false
      end
    end
  end

  describe '#inject_ability_rules' do
    let(:ability) do
      <<~RUBY
        class Ability
          include Hyrax::Ability

          def custom_permissions
            # existing
            can :read, :things
          end
        end
      RUBY
    end

    def with_ability(contents)
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'app/models'))
        File.write(File.join(dir, 'app/models/ability.rb'), contents) if contents
        Dir.chdir(dir) { yield }
      end
    end

    it 'adds the rules at the top of custom_permissions, leaving existing rules after them' do
      with_ability(ability) do
        described_class.new.inject_ability_rules
        result = File.read('app/models/ability.rb')

        expect(result).to include('can :access, :coar_notify')
        expect(result.index('can :access, :coar_notify')).to be < result.index('can :read, :things')
        expect { RubyVM::InstructionSequence.compile(result) }.not_to raise_error
      end
    end

    it 'does not add the rules twice' do
      with_ability(ability) do
        described_class.new.inject_ability_rules
        once = File.read('app/models/ability.rb')
        described_class.new.inject_ability_rules

        expect(File.read('app/models/ability.rb')).to eq(once)
      end
    end

    it 'leaves an ability without custom_permissions alone' do
      with_ability("class Ability; end\n") do
        expect { described_class.new.inject_ability_rules }.not_to raise_error
        expect(File.read('app/models/ability.rb')).to eq("class Ability; end\n")
      end
    end

    it 'does nothing when the host has no ability.rb' do
      with_ability(nil) do
        expect { described_class.new.inject_ability_rules }.not_to raise_error
        expect(File.exist?('app/models/ability.rb')).to be false
      end
    end
  end

  describe '#add_schema_to_work_types' do
    let(:model) do
      <<~RUBY
        class Dataset < Hyrax::Work
          include Hyrax::Schema(:basic_metadata)
          include Hyrax::Schema(:dataset)
        end
      RUBY
    end
    let(:indexer) do
      <<~RUBY
        class DatasetIndexer < Hyrax::Indexers::PcdmObjectIndexer(Dataset)
          include Hyrax::Indexer(:basic_metadata)
          include Hyrax::Indexer(:dataset)

          # custom
        end
      RUBY
    end

    def in_work_app(files)
      Dir.mktmpdir do |dir|
        files.each do |path, contents|
          FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
          File.write(File.join(dir, path), contents)
        end
        Dir.chdir(dir) { yield }
      end
    end

    def generate(*types)
      described_class.new([], work_types: types).add_schema_to_work_types
    end

    it 'adds the schema and indexer after the last existing include, keeping them valid Ruby' do
      in_work_app('app/models/dataset.rb' => model, 'app/indexers/dataset_indexer.rb' => indexer) do
        generate('Dataset')

        expect(File.read('app/models/dataset.rb')).to include("  include Hyrax::Schema(:dataset)\n  include Hyrax::Schema(:coar_notify_metadata)\n")
        expect(File.read('app/indexers/dataset_indexer.rb'))
          .to include("  include Hyrax::Indexer(:dataset)\n  include Hyrax::Indexer(:coar_notify_metadata)\n\n  # custom")
        %w[app/models/dataset.rb app/indexers/dataset_indexer.rb].each do |f|
          expect { RubyVM::InstructionSequence.compile(File.read(f)) }.not_to raise_error
        end
      end
    end

    it 'does not add anything twice' do
      in_work_app('app/models/dataset.rb' => model, 'app/indexers/dataset_indexer.rb' => indexer) do
        generate('Dataset')
        once = [File.read('app/models/dataset.rb'), File.read('app/indexers/dataset_indexer.rb')]
        generate('Dataset')

        expect([File.read('app/models/dataset.rb'), File.read('app/indexers/dataset_indexer.rb')]).to eq(once)
      end
    end

    it 'leaves a work type with no Hyrax::Schema (ActiveFedora) alone' do
      af = "class Legacy < ActiveFedora::Base\nend\n"
      in_work_app('app/models/legacy.rb' => af) do
        expect { generate('Legacy') }.not_to raise_error
        expect(File.read('app/models/legacy.rb')).to eq(af)
      end
    end

    it 'skips work types whose files do not exist' do
      in_work_app('app/models/.keep' => '') do
        expect { generate('Missing') }.not_to raise_error
      end
    end

    it 'defaults to every registered curation concern type' do
      allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return(['Dataset'])
      in_work_app('app/models/dataset.rb' => model) do
        described_class.new.add_schema_to_work_types

        expect(File.read('app/models/dataset.rb')).to include('coar_notify_metadata')
      end
    end

    it 'only touches the requested work types' do
      other = model.sub('Dataset', 'Other')
      in_work_app('app/models/dataset.rb' => model, 'app/models/other.rb' => other) do
        generate('Dataset')

        expect(File.read('app/models/other.rb')).to eq(other)
      end
    end
  end
end

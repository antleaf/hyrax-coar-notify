# frozen_string_literal: true

require 'rails/generators'

module Hyrax
  module CoarNotify
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Installs Hyrax::CoarNotify into a host Hyrax application.'

      class_option :work_types, type: :array, default: nil,
                                desc: 'Work types to enable endorsements/reviews on (default: every registered curation concern type)'

      def copy_initializer
        template 'hyrax_coar_notify_config.rb', 'config/initializers/hyrax_coar_notify.rb'
      end

      def copy_metadata_config
        template 'coar_notify_metadata.yaml', 'config/metadata/coar_notify_metadata.yaml' if File.exist?(File.expand_path('templates/coar_notify_metadata.yaml', __dir__))
      end

      def mount_engine
        route "mount Hyrax::CoarNotify::Engine => '/coar_notify'"
      end

      def install_migrations
        rake 'hyrax_coar_notify:install:migrations' rescue nil
      end

      def add_schema_to_work_types
        work_type_names.each do |name|
          add_line_after_last_match("app/models/#{name.underscore}.rb", /include Hyrax::Schema\(/,
                                    'include Hyrax::Schema(:coar_notify_metadata)')
          add_line_after_last_match("app/indexers/#{name.underscore}_indexer.rb", /include Hyrax::Indexer\(/,
                                    'include Hyrax::Indexer(:coar_notify_metadata)')
        end
      end

      ABILITY_FILE = 'app/models/ability.rb'

      def inject_ability_rules
        return unless File.exist?(ABILITY_FILE)
        return if File.read(ABILITY_FILE).include?('coar_notify')

        unless File.read(ABILITY_FILE).match?(/def custom_permissions\b/)
          say_status :skip, "#{ABILITY_FILE} has no custom_permissions method; add the COAR Notify rules by hand (see docs/INSTALLATION.md)", :yellow
          return
        end

        insert_into_file ABILITY_FILE, after: /def custom_permissions.*\n/ do
          <<~RUBY.gsub(/^(?=.)/, '    ')
            if current_user.admin? || user_groups.include?(Hyrax::CoarNotify.config.manager_role.to_s)
              can [:manage], Hyrax::CoarNotify::NotifyService
              can [:manage], Hyrax::CoarNotify::NotifyInbox
              can :access, :coar_notify
            end
          RUBY
        end
      end

      def inject_sidebar_link
        sidebar_file = 'app/views/hyrax/dashboard/_sidebar.html.erb'
        return unless File.exist?(sidebar_file)

        content = File.read(sidebar_file)
        return if content.include?('coar_notify')

        insert_into_file sidebar_file, before: '</ul>' do
          <<~ERB
            <% if can?(:access, :coar_notify) %>
              <li class="nav-item">
                <%= link_to hyrax_coar_notify.root_path, class: "nav-link", title: t('coar_notify.title') do %>
                  <span class="fa fa-bell" aria-hidden="true"></span> <span class="sidebar-action-text"><%= t('coar_notify.title') %></span>
                <% end %>
              </li>
            <% end %>
          ERB
        end
      end

      private

      def work_type_names
        options[:work_types] || (defined?(Hyrax) ? Hyrax.config.registered_curation_concern_types : [])
      end

      # Adds `line` after the last line matching `pattern`, matching its indentation. Skips (with a
      # message) when the file is missing, already has the line, or has no line to anchor on, e.g. an
      # ActiveFedora work type, which has no Hyrax::Schema to extend.
      def add_line_after_last_match(path, pattern, line)
        return say_status(:skip, "#{path} not found", :yellow) unless File.exist?(path)

        lines = File.readlines(path)
        return if lines.any? { |l| l.include?(line) }

        anchor = lines.reverse.find { |l| l.match?(pattern) }
        return say_status(:skip, "#{path} has no #{pattern.source}; add `#{line}` by hand", :yellow) unless anchor

        insert_into_file path, "#{anchor[/\A\s*/]}#{line}\n", after: anchor
      end
    end
  end
end

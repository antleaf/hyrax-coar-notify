# frozen_string_literal: true

require 'rails/generators'

module Hyrax
  module CoarNotify
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Installs Hyrax::CoarNotify into a host Hyrax application.'

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

      def inject_sidebar_link
        sidebar_file = 'app/views/hyrax/dashboard/_sidebar.html.erb'
        return unless File.exist?(sidebar_file)

        content = File.read(sidebar_file)
        return if content.include?('coar_notify')

        append_to_file sidebar_file, <<~ERB
          <li>
            <%= link_to (defined?(hyrax_coar_notify) ? hyrax_coar_notify.root_path : "/coar_notify"), class: "nav-link", title: I18n.t('coar_notify.title') do %>
              <span class="fa fa-bell" aria-hidden="true"></span> <span class="sidebar-action-text"><%= I18n.t('coar_notify.title') %></span>
            <% end %>
          </li>
        ERB
      end
    end
  end
end

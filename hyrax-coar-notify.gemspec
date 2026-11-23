# frozen_string_literal: true

require_relative 'lib/hyrax/coar_notify/version'

Gem::Specification.new do |spec|
  spec.name          = 'hyrax-coar-notify'
  spec.version       = Hyrax::CoarNotify::VERSION
  spec.authors       = ['Hyrax COAR Notify Contributors']
  spec.email         = ['us@cottagelabs.com']

  spec.summary       = 'COAR Notify protocol integration for Hyrax repositories'
  spec.description   = 'A Rails Engine gem enabling Hyrax 5.2+ digital repositories to integrate seamlessly with COAR Notify protocol services.'
  spec.homepage      = 'https://github.com/antleaf/hyrax-coar-notify'
  spec.license       = 'Apache-2.0'

  spec.files         = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '~> 7.2'
  spec.add_dependency 'hyrax', '~> 5.2'
  spec.add_dependency 'faraday', '>= 1.0'
  spec.add_dependency 'coar_notify_inbox'

  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'i18n-tasks', '~> 1.0'
end

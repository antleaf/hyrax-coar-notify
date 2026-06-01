# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Dataset`
class Dataset < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:dataset)
end

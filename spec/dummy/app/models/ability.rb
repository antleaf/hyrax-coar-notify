# frozen_string_literal: true

# Like Hyrax::Ability, grants nothing for the :coar_notify subject by default; hosts add their own rules.
class Ability
  include CanCan::Ability

  def initialize(_user); end
end

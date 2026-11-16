# frozen_string_literal: true

class User < ApplicationRecord
  attr_accessor :password
  # Role names, like Hydra::RoleManagement's User#groups
  attr_writer :groups

  def groups
    Array(@groups)
  end
end

class Ability
  include Hydra::Ability
  
  include Hyrax::Ability
  self.ability_logic += [:everyone_can_create_curation_concerns, :custom_permissions]

  # Define any customized permissions here.
  def custom_permissions
    # Limits deleting objects to a the admin user
    #
    # if current_user.admin?
    #   can [:destroy], ActiveFedora::Base
    # end

    # Limits creating new objects to a specific group
    #
    # if user_groups.include? 'special_group'
    #   can [:create], ActiveFedora::Base
    # end

    return unless current_user.admin?
    can [:manage], NotifyService
    can [:manage], NotifyInbox
    can :access, :notify_dashboard
    can :access, :manage_notify_connections
  end
end

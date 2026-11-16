# frozen_string_literal: true

# Stands in for a Hyrax host's ApplicationController: Devise-style current_user/authenticate_user!
# and CanCan's can?/authorize!. The signed-in user comes from session[:user_id] so specs can set it.
class ApplicationController < ActionController::Base
  include CanCan::ControllerAdditions

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    redirect_to main_app.new_user_session_url unless current_user
  end
end

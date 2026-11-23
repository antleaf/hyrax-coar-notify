# frozen_string_literal: true

Rails.application.routes.draw do
  mount Hyrax::CoarNotify::Engine => '/coar_notify'

  root to: proc { [200, {}, ['home']] }
  get '/users/sign_in', to: proc { [200, {}, ['sign in']] }, as: :new_user_session
end

Hyrax::CoarNotify::Engine.routes.draw do
  root to: "dashboard#index"
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "manage_connections", to: "dashboard#manage_connections", as: :manage_connections
  get "manage_notify_connections", to: "dashboard#manage_connections", as: :manage_notify_connections

  resources :notify_inboxes, except: [:show]
  resources :notify_services, except: [:show] do
    member do
      post 'request_endorsement'
      post 'request_review'
    end
  end
end

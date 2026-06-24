Rails.application.routes.draw do
  mount Riiif::Engine => 'images', as: :riiif if Hyrax.config.iiif_image_server?
        mount BrowseEverything::Engine => '/browse'
  mount Blacklight::Engine => '/'

  authenticate :user, lambda { |u| u.admin? } do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  
  concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  # Add routes for the Notify Dashboard and Notify Inboxes
  resources :notify_inboxes, except: [:index, :show]
  resources :notify_services, except: [:index, :show] do
    member do
      post 'request_endorsement'
      post 'request_review'
    end
  end
  get "notify_dashboard", to: "notify_dashboard#index"
  get "manage_notify_connections", to: "notify_dashboard#manage_connections", as: :manage_notify_connections

  devise_for :users
  mount Hydra::RoleManagement::Engine => '/'
  mount Qa::Engine => '/authorities'
  mount Hyrax::Engine, at: '/'
  mount CoarNotifyInbox::Engine => "/coar_notify_inbox"
  resources :welcome, only: 'index'
  root 'hyrax/homepage#index'
  curation_concerns_basic_routes
  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end

Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :dashboard do
    get "home/index"
    resources :products do
      member do
        post :generate_variants
        delete :delete_image
      end
      resources :product_options, only: %i[create], shallow: true
      resources :product_variants, only: %i[update], shallow: true
    end
    resources :product_options, only: %i[destroy]
    resources :product_variants, only: %i[destroy]
    resources :collections
    resources :categories
    resources :orders, only: %i[index show update]
    get   'inventory',            to: 'inventories#index',         as: :inventory
    patch 'inventory/update_all', to: 'inventories#update_all',    as: :inventory_update_all
    get   'inventory/movements',  to: 'inventory_movements#index', as: :inventory_movements
    root to: "home#index"
  end

  # Storefront
  resources :products,    only: [:index, :show]
  resources :categories,  only: [:show], param: :slug
  resources :collections, only: [:show], param: :slug
  resource  :cart, only: [:show, :update, :destroy] do
    post "add", to: "carts#add", as: :add_to
  end
  resource  :checkout, only: [:new, :create] do
    get :success
  end
  get "search", to: "home#search", as: :search
  root "home#index"
end

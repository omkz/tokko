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
    
    # Inventory Management
    get 'inventory', to: 'inventories#index'
    patch 'inventory/update_all', to: 'inventories#update_all'
    root to: "home#index"
  end

  # Storefront
  resources :products, only: [:show]
  resources :categories, only: [:show], param: :slug
  resources :collections, only: [:show], param: :slug
  resource :cart, only: [:show, :update, :destroy] do
    post "add", to: "carts#add", as: :add_to
  end

  resource :checkout, only: [:new, :create] do
    get :success
  end
  
  root "home#index"
end

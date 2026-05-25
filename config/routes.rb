Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :magic_link, only: [ :new, :create, :show ]
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
    resources :users, only: %i[index update]
    resources :coupons
    resources :filter_groups do
      resources :filter_options, only: [ :create ], shallow: true
    end
    resources :filter_options, only: [ :destroy ]
    get   "inventory",            to: "inventories#index",         as: :inventory
    patch "inventory/update_all", to: "inventories#update_all",    as: :inventory_update_all
    get   "inventory/movements",  to: "inventory_movements#index", as: :inventory_movements
    root to: "home#index"
  end

  # Storefront
  resources :products,    only: [ :index, :show ], param: :slug
  resources :categories,  only: [ :show ], param: :slug
  resources :collections, only: [ :show ], param: :slug
  resource  :account,     only: [ :show, :edit, :update ]
  resources :addresses,   only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member { patch :set_default }
  end
  resources :orders,      only: [ :index, :show ]
  resources :wishlist_items, only: [ :index, :create, :destroy ]
  post "coupons/validate", to: "coupons#validate", as: :validate_coupon
  resource  :cart, only: [ :show, :update, :destroy ] do
    post "add", to: "carts#add", as: :add_to
  end
  resource :checkout, only: [ :new, :create ] do
    get :success
    get :payment_success
  end

  namespace :webhooks do
    post :stripe, to: "stripe#create"
  end
  root "home#index"

  match "/404", to: "errors#not_found",             via: :all
  match "/422", to: "errors#unprocessable_entity",   via: :all
  match "/500", to: "errors#internal_server_error",  via: :all
end

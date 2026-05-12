Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :dashboard do
    resources :products do
      member do
        post :generate_variants
        delete :delete_image
      end
    end
    resources :product_options, only: %i[create destroy], shallow: true
    resources :product_variants, only: %i[update destroy], shallow: true
    root to: "products#index"
  end

  # Storefront
  resources :products, only: [:show]
  root "home#index"
end

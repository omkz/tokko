Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :products do
    member do
      post :generate_variants
    end
    resources :product_options, only: %i[create destroy], shallow: true
    resources :product_variants, only: %i[update destroy], shallow: true
  end

  root "products#index"
end

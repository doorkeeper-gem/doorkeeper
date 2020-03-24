Rails.application.routes.draw do
  use_doorkeeper

  resources :semi_protected_resources
  resources :full_protected_resources

  get "metal.json" => "metal#index"

  get "/callback", to: "home#callback"
  get "/sign_in",  to: "home#sign_in"

  root to: "home#index"
end

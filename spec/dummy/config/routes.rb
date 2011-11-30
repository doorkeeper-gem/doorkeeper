Rails.application.routes.draw do
  mount Doorkeeper::Engine => "/oauth"
  get '/callback', :to => "home#callback"
  get '/sign_in',  :to => "home#sign_in"
  resources :semi_protected_resources
  resources :full_protected_resources
  root :to => "home#index"
end

Rails.application.routes.draw do
  mount Doorkeeper::Engine => "/oauth"
  get '/callback', :to => "home#callback"
  root :to => "home#index"
end

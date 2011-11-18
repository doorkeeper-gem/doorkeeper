Rails.application.routes.draw do
  mount Doorkeeper::Engine => "/oauth"
  root :to => "home#index"
end

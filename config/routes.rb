Doorkeeper::Engine.routes.draw do
  get    'authorize', :to => "authorizations#new",     :as => :authorization
  post   'authorize', :to => "authorizations#create",  :as => :authorization
  delete 'authorize', :to => "authorizations#destroy", :as => :authorization
  post   'token',     :to => "tokens#create",          :as => :token

  resources :applications
end

Rails.application.routes.draw do

  scope '/oauth', :module => 'doorkeeper', :as => 'oauth' do
    get    'authorize', :to => "authorizations#new",     :as => :authorization
    post   'authorize', :to => "authorizations#create",  :as => :authorization
    delete 'authorize', :to => "authorizations#destroy", :as => :authorization
    post   'token',     :to => "tokens#create",          :as => :token
    resources :applications
    resources :authorized_applications, :only => [:index, :destroy]
  end

  get '/callback', :to => "home#callback"
  get '/sign_in',  :to => "home#sign_in"
  resources :semi_protected_resources
  resources :full_protected_resources
  root :to => "home#index"
end

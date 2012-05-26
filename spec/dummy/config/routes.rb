Rails.application.routes.draw do
  use_doorkeeper

  scope 'space' do
    use_doorkeeper do
      controllers :authorization => 'custom_authorizations'
    end
  end

  get '/callback', :to => "home#callback"
  get '/sign_in',  :to => "home#sign_in"
  resources :semi_protected_resources
  resources :full_protected_resources
  root :to => "home#index"
end

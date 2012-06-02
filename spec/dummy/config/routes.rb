Rails.application.routes.draw do
  use_doorkeeper

  scope 'space' do
    use_doorkeeper do
      controllers :authorizations => 'custom_authorizations',
                  :tokens => 'custom_authorizations',
                  :applications => 'custom_authorizations'

      as :authorizations => 'custom_auth',
         :tokens => 'custom_token'
    end
  end

  get 'metal.json' => 'metal#index'
  get '/callback', :to => "home#callback"
  get '/sign_in',  :to => "home#sign_in"
  resources :semi_protected_resources
  resources :full_protected_resources
  root :to => "home#index"
end

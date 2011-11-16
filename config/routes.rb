Doorkeeper::Engine.routes.draw do
  get    'authorize', :to => "authorizations#new"
  post   'authorize', :to => "authorizations#create"
  delete 'authorize', :to => "authorizations#destroy"
  post   'token',     :to => "tokens#create"
end

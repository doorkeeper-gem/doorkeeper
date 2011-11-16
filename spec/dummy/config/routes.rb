Rails.application.routes.draw do
  mount Doorkeeper::Engine => "/oauth"
end

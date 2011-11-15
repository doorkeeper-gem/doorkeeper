Rails.application.routes.draw do

  mount Doorkeeper::Engine => "/doorkeeper"
end

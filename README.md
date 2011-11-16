# Doorkeeper - awesome oauth provider for your Rails app.

## Installation
Put this in your Gemfile

`gem 'doorkeeper'`

## Configuration
Mount Doorkeeper routes to your app

`
  Rails.application.routes.draw do
    #Your routes

    mount Doorkeeper::Engine => "/oauth"
  end
`

This will mount following routes
get /oauth/authorize
post /oauth/authorize
delete /oauth/authorize
post /oauth/token

You need to configure Doorkeeper in order to provide
resource_owner model and authentication block
initializers/doorkeeper.rb

`
  Doorkeeper.configure do
    resource_owner_model User, :id
    resource_owner_authentication do
      authenticate_user
    end
  end
`

TODO:
  Provide a way to generate views, so far we serve authorization#new view
  Generator to create a template initializer

## Protecting resources
In the controller add the before_filter
to authorize the token

`
  class TheController < ApplicationController
    require_oauth_token #For all actions
    require_oauth_token :only => :index #Require token only for index action
    require_oauth_token :except => :show #Require token for all actions except show
  end
`

If the token is not valid it would serve 40x response.


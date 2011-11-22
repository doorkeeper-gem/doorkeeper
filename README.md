# Doorkeeper - awesome oauth provider for your Rails app.

[![Build Status](https://secure.travis-ci.org/applicake/doorkeeper.png)](http://travis-ci.org/applicake/doorkeeper)

## Installation

Put this in your Gemfile:

    gem 'doorkeeper'

Run the installation generator with:

    rails generate doorkeeper:install

This will generate the doorkeeper initializer and the oauth tables migration. Don't forget to run the migration in your application:

    rake db:migrate

## Configuration

Mount Doorkeeper routes to your app

    Rails.application.routes.draw do
      # Your routes
      mount Doorkeeper::Engine => "/oauth"
    end

This will mount following routes:

    GET    /oauth/authorize
    POST   /oauth/authorize
    DELETE /oauth/authorize
    POST   /oauth/token

You need to configure Doorkeeper in order to provide resource_owner model and authentication block `initializers/doorkeeper.rb`

    Doorkeeper.configure do
      resource_owner_authenticator do
        current_user || redirect_to('/sign_in', :alert => "Needs sign in.") # returns nil if current_user is not logged in
      end
    end

If you use devise, you may want to use warden to authenticate the block:

    resource_owner_authenticator do
      current_user || warden.authenticate!(:scope => :user)
    end

## Protecting resources (a.k.a your API endpoint)

In the controller add the before_filter to authorize the token

    class ProtectedResourcesController < ApplicationController
      require_oauth_token # For all actions
      require_oauth_token :only => :index # Require token only for index action
      require_oauth_token :except => :show # Require token for all actions except show
    end

If the token is not valid it would serve 40x response.

## TODO:

- Provide a way to generate views, so far we serve authorization#new view Generator to create a template initializer
- Add config option to redirect path when resource owner is not logged in

# Doorkeeper - awesome oauth provider for your Rails app.

[![Build Status](https://secure.travis-ci.org/applicake/doorkeeper.png)](http://travis-ci.org/applicake/doorkeeper)

Doorkeeper is a gem that makes it easy to introduce oauth2 provider
functionality to your application.

So far it supports only Authorization Code
flow, but we will gradually introduce other flows.

For more information about Oauth2 go to
[Oauth2 Specs (Draft)](http://tools.ietf.org/html/draft-ietf-oauth-v2-22)

## Installation

Put this in your Gemfile:

    gem 'doorkeeper'

Run the installation generator with:

    rails generate doorkeeper:install

This will generate the doorkeeper initializer and the oauth tables migration. Don't forget to run the migration in your application:

    rake db:migrate

## Configuration

The installation will mount the Doorkeeper routes to your app like this:

    Rails.application.routes.draw do
      mount Doorkeeper::Engine => "/oauth"
      # your routes
    end

This will mount following routes:

    GET       /oauth/authorize
    POST      /oauth/authorize
    DELETE    /oauth/authorize
    POST      /oauth/token
    resources /oauth/applications

You need to configure Doorkeeper in order to provide resource_owner model and authentication block `initializers/doorkeeper.rb`

    Doorkeeper.configure do
      resource_owner_authenticator do |routes|
        current_user || redirect_to('/sign_in', :alert => "Needs sign in.") # returns nil if current_user is not logged in
      end
    end

If you use devise, you may want to use warden to authenticate the block:

    resource_owner_authenticator do |routes|
      current_user || warden.authenticate!(:scope => :user)
    end

## Protecting resources (a.k.a your API endpoint)

In the controller add the before_filter to authorize the token

    class ProtectedResourcesController < ApplicationController
      doorkeeper_for :all # For all actions
      doorkeeper_for :only   => :index # Require token only for index action
      doorkeeper_for :except => :show  # Require token for all actions except show
    end

## Creating and using client applications

To start using OAuth 2 as a client first fire up the server with `rails server`, go to `/oauth/applications` and create an application for your client.

Choose a name and a callback url for it. If you use oauth2 gem you can specify your just generated client as:

    require 'oauth2'
    client_id     = '...' # your client's id
    client_secret = '...' # your client's secret
    redirect_uri  = '...' # your client's redirect uri
    client = OAuth2::Client.new(
      client_id,
      client_secret,
      :site => "http://localhost:3000"
    )

If you changed the default mount path `/oauth` in your `routes.rb` you need to specify it in the oauth client as `:authorize_url` and `:token_url`. For more information, check the oauth2 gem documentation.

After that you can try to request an authorization code with the oauth2 gem as follow:

    client.auth_code.authorize_url(:redirect_uri => redirect_uri)
    # => http://localhost:3000/oauth/authorize?response_type=code&client_id=...&redirect_uri=...

If you visit the returned url, you'll see a screen to authorize your app. Click on `authorize` and you'll be redirected to your client redirect url.

Grab the code from the redirect url and request a access token with the following:

    token = client.auth_code.get_token(parms[:code])

You now have an access token to access you protected resources.

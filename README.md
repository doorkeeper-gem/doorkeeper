# Doorkeeper - awesome oauth provider for your Rails app.

[![Build Status](https://secure.travis-ci.org/applicake/doorkeeper.png)](http://travis-ci.org/applicake/doorkeeper)

Doorkeeper is a gem that makes it easy to introduce OAuth 2 provider functionality to your application.

So far it supports only Authorization Code flow, but we will [gradually introduce other flows](https://github.com/applicake/doorkeeper/wiki/Supported-Features).

For more information about OAuth 2 go to [OAuth 2 Specs (Draft)](http://tools.ietf.org/html/draft-ietf-oauth-v2-22).

## Installation

Put this in your Gemfile:

``` ruby
gem 'doorkeeper'
```

Run the installation generator with:

    rails generate doorkeeper:install

This will generate the doorkeeper initializer and the oauth tables migration. Don't forget to run the migration in your application:

    rake db:migrate

## Configuration

The installation will mount the Doorkeeper routes to your app like this:

``` ruby
Rails.application.routes.draw do
  mount Doorkeeper::Engine => "/oauth"
  # your routes
end
```

This will mount following routes:

    GET       /oauth/authorize
    POST      /oauth/authorize
    DELETE    /oauth/authorize
    POST      /oauth/token
    resources /oauth/applications

You need to configure Doorkeeper in order to provide resource_owner model and authentication block `initializers/doorkeeper.rb`

``` ruby
Doorkeeper.configure do
  resource_owner_authenticator do |routes|
    current_user || redirect_to('/sign_in', :alert => "Needs sign in.") # returns nil if current_user is not logged in
  end
end
```

If you use devise, you may want to use warden to authenticate the block:

``` ruby
resource_owner_authenticator do |routes|
  current_user || warden.authenticate!(:scope => :user)
end
```

## Protecting resources (a.k.a your API endpoint)

In your api controller, add the `doorkeeper_for` to require the oauth token:

``` ruby
class Api::V1::ProtectedResourcesController < Api::V1::ApiController
  doorkeeper_for :all              # Require access token for all actions
  doorkeeper_for :only   => :index # Only for index action
  doorkeeper_for :except => :show  # All actions except show

  # your actions
end
```

You don't need to setup any before filter, `doorkeeper_for` will handle that for you.

## Authenticated resource owner

If you want to return data based on the current resource owner for example, the access token user credentials, you'll need to define a method in your controller to return the resource owner instance:

``` ruby
class Api::V1::CredentialsController < Api::V1::ApiController
  doorkeeper_for :all
  respond_to     :json

  # GET /api/v1/me.json
  def me
    respond_with current_resource_owner
  end

  private

  # Find the user that owns the access token
  def current_resource_owner
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end
```

## Other resources

### Live demo

Check out this [live demo](http://doorkeeper-provider.herokuapp.com) hosted on heroku. For more demos check out [the wiki](https://github.com/applicake/doorkeeper/wiki/Example-Applications).

### Client applications

After you set up the provider, you may want to create a client application to test the integration. Check out these [client examples](https://github.com/applicake/doorkeeper/wiki/Example-Applications) in our wiki or follow this [tutorial here](https://github.com/applicake/doorkeeper/wiki/Testing-your-provider-with-OAuth2-gem).

### Contributing/Development

Want to contribute and don't know where to start? Check out [features we're missing](https://github.com/applicake/doorkeeper/wiki/Supported-Features), create [example apps](https://github.com/applicake/doorkeeper/wiki/Example-Applications), integrate the gem with your app and let us know!

Also, check out our [contributing guidelines page](https://github.com/applicake/doorkeeper/wiki/Contributing).

### Supported ruby versions

All supported ruby versions are [listed here](https://github.com/applicake/doorkeeper/wiki/Supported-Ruby-versions)

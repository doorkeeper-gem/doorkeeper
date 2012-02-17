# Doorkeeper - awesome oauth provider for your Rails app.

[![Build Status](https://secure.travis-ci.org/applicake/doorkeeper.png)](http://travis-ci.org/applicake/doorkeeper)

Doorkeeper is a gem that makes it easy to introduce OAuth 2 provider functionality to your application.

The gem is under constant development. It is based in the [version 22 of the OAuth specification](http://tools.ietf.org/html/draft-ietf-oauth-v2-22) and it still does not support all OAuth features.

For more information about the supported features, check out the related [page in the wiki](https://github.com/applicake/doorkeeper/wiki/Supported-Features). For more information about OAuth 2 go to [OAuth 2 Specs (Draft)](http://tools.ietf.org/html/draft-ietf-oauth-v2-22).

## Installation

Put this in your Gemfile:

``` ruby
gem 'doorkeeper', '~> 0.3.0'
```

Run the installation generator with:

    rails generate doorkeeper:install

This will generate the doorkeeper initializer and the OAuth tables migration. Don't forget to run the migration in your application:

    rake db:migrate

## Configuration

The installation script will automatically add the Doorkeeper routes into your app, like this:

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

If you use [devise](https://github.com/plataformatec/devise), you may want to use warden to authenticate the block:

``` ruby
resource_owner_authenticator do |routes|
  current_user || warden.authenticate!(:scope => :user)
end
```

## Protecting resources with OAuth (a.k.a your API endpoint)

To protect your API with OAuth, doorkeeper only requires you to call `doorkeeper_for` helper, specifying the actions you want to protect.

For example, if you have a products controller under api/v1, you can require the OAuth authentication with:

``` ruby
class Api::V1::ProductsController < Api::V1::ApiController
  doorkeeper_for :all                     # Require access token for all actions
  doorkeeper_for :all, :except => :index  # All actions except show
  doorkeeper_for :index, :show            # Only for index and show action

  # your actions
end
```

You don't need to setup any before filter, `doorkeeper_for` will handle that for you.

You can pass `if` or `unless` blocks that would specify when doorkeeper has to guard the access.

``` ruby
class Api::V1::ProductsController < Api::V1::ApiController
  doorkeeper_for :all, :if => lambda { request.xhr? }
end
```

### Access Token Scopes

You can also require the access token to have specific scopes in certain actions:

```ruby
class Api::V1::ProductsController < Api::V1::ApiController
  doorkeeper_for :index, :show,    :scopes => [:public]
  doorkeeper_for :update, :create, :scopes => [:admin, :write]
end
```

For a more detailed explanation about scopes usage, check out the related [page in the wiki](https://github.com/applicake/doorkeeper/wiki/Using-Scopes).

### Authenticated resource owner

If you want to return data based on the current resource owner, in other words, the access token owner, you may want to define a method in your controller that returns the resource owner instance:

``` ruby
class Api::V1::CredentialsController < Api::V1::ApiController
  doorkeeper_for :all
  respond_to     :json

  # GET /me.json
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

In this example, we're returning the credentials (`me.json`) of the access token owner.

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

## Additional information

### Maintainers

- Felipe Elias Philipp ([github.com/felipeelias](https://github.com/felipeelias))
- Piotr Jakubowski ([github.com/piotrj](https://github.com/piotrj))

### Contributors

Thanks to all our [awesome contributors](https://github.com/applicake/doorkeeper/contributors)!

### License

MIT License. Copyright 2011 Applicake. [http://applicake.com](http://applicake.com)

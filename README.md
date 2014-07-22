# Doorkeeper - awesome oauth provider for your Rails app.

[![Build Status](https://travis-ci.org/doorkeeper-gem/doorkeeper.png?branch=master)](https://travis-ci.org/doorkeeper-gem/doorkeeper)
[![Dependency Status](https://gemnasium.com/applicake/doorkeeper.png?travis)](https://gemnasium.com/applicake/doorkeeper)
[![Code Climate](https://codeclimate.com/github/applicake/doorkeeper.png)](https://codeclimate.com/github/applicake/doorkeeper)
[![Gem Version](https://badge.fury.io/rb/doorkeeper.png)](https://rubygems.org/gems/doorkeeper)

Doorkeeper is a gem that makes it easy to introduce OAuth 2 provider functionality to your application.

## Table of Contents

- [Useful links](#useful-links)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
    - [Active Record](#active-record)
    - [Mongoid / MongoMapper](#mongoid--mongomapper)
        - [Mongoid indexes](#mongoid-indexes)
        - [MongoMapper indexes](#mongomapper-indexes)
    - [Routes](#routes)
    - [Authenticating](#authenticating)
- [Protecting resources with OAuth (a.k.a your API endpoint)](#protecting-resources-with-oauth-aka-your-api-endpoint)
    - [ActionController::Metal integration](#actioncontrollermetal-integration)
    - [Route Constraints and other integrations](#route-constraints-and-other-integrations)
    - [Access Token Scopes](#access-token-scopes)
    - [Authenticated resource owner](#authenticated-resource-owner)
    - [Applications list](#applications-list)
- [Other customizations](#other-customizations)
- [Upgrading](#upgrading)
- [Development](#development)
- [Contributing](#contributing)
- [Other resources](#other-resources)
    - [Wiki](#wiki)
    - [Live demo](#live-demo)
    - [Screencast](#screencast)
    - [Client applications](#client-applications)
    - [Contributors](#contributors)
    - [License](#license)

## Useful links

- For documentation, please check out our [wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki)
- For general questions, please post it in [stack overflow](http://stackoverflow.com/questions/tagged/doorkeeper)

## Requirements

- Ruby >1.9.3
- Rails >3.1
- ORM ActiveRecord, Mongoid, MongoMapper

## Installation

Put this in your Gemfile:

``` ruby
gem 'doorkeeper'
```

Run the installation generator with:

    rails generate doorkeeper:install

This will install the doorkeeper initializer into `config/initializers/doorkeeper.rb`.

## Configuration

### Active Record

By default doorkeeper is configured to use active record, so to start you have
to generate the migration tables:

    rails generate doorkeeper:migration

Don't forget to run the migration with:

    rake db:migrate

### Mongoid / MongoMapper

Doorkeeper currently supports MongoMapper, Mongoid 2 and 3. To start using it,
you have to set the `orm` configuration:

``` ruby
Doorkeeper.configure do
  orm :mongoid2 # or :mongoid3, :mongoid4, :mongo_mapper
end
```

#### Mongoid indexes

Make sure you create indexes for doorkeeper models. You can do this either by
running `rake db:mongoid:create_indexes` or (if you're using Mongoid 2) by
adding `autocreate_indexes: true` to your `config/mongoid.yml`

#### MongoMapper indexes

Generate the `db/indexes.rb` file and create indexes for the doorkeeper models:

    rails generate doorkeeper:mongo_mapper:indexes
    rake db:index

### Routes

The installation script will also automatically add the Doorkeeper routes into
your app, like this:

``` ruby
Rails.application.routes.draw do
  use_doorkeeper
  # your routes
end
```

This will mount following routes:

    GET       /oauth/authorize/:code
    GET       /oauth/authorize
    POST      /oauth/authorize
    PUT       /oauth/authorize
    DELETE    /oauth/authorize
    POST      /oauth/token
    POST      /oauth/revoke
    resources /oauth/applications
    GET       /oauth/authorized_applications
    DELETE    /oauth/authorized_applications/:id
    GET       /oauth/token/info

For more information on how to customize routes, check out [this page on the
wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki/Customizing-routes).

### Authenticating

You need to configure Doorkeeper in order to provide `resource_owner` model
and authentication block `initializers/doorkeeper.rb`

``` ruby
Doorkeeper.configure do
  resource_owner_authenticator do
    User.find_by_id(session[:current_user_id]) || redirect_to(login_url)
  end
end
```

This code is run in the context of your application so you have access to your
models, session or routes helpers. However, since this code is not run in the
context of your application's `ApplicationController` it doesn't have access to
the methods defined over there.

If you use [devise](https://github.com/plataformatec/devise), you may want to
use warden to authenticate the block:

``` ruby
resource_owner_authenticator do
  current_user || warden.authenticate!(:scope => :user)
end
```

Side note: when using devise you have access to `current_user` as devise extends
entire `ActionController::Base` with the `current_#{mapping}`.

If you are not using devise, you may want to check other ways of
authentication
[here](https://github.com/doorkeeper-gem/doorkeeper/wiki/Authenticating-using-Clearance-or-DIY).

## Protecting resources with OAuth (a.k.a your API endpoint)

To protect your API with OAuth, doorkeeper only requires you to call
`doorkeeper_for` helper, specifying the actions you want to protect.

For example, if you have a products controller under api/v1, you can require
the OAuth authentication with:

``` ruby
class Api::V1::ProductsController < Api::V1::ApiController
  doorkeeper_for :all                 # Require access token for all actions
  doorkeeper_for :all, except: :index # All actions except index
  doorkeeper_for :index, :show        # Only for index and show action

  # your actions
end
```

You don't need to setup any before filter, `doorkeeper_for` will handle that
for you.

You can pass `if` or `unless` blocks that would specify when doorkeeper has to
guard the access.

``` ruby
class Api::V1::ProductsController < Api::V1::ApiController
  doorkeeper_for :all, :if => lambda { request.xhr? }
end
```

### ActionController::Metal integration

The `doorkeeper_for` filter is intended to work with ActionController::Metal
too. You only need to include the required `ActionController` modules:

```ruby
class MetalController < ActionController::Metal
  include AbstractController::Callbacks
  include ActionController::Head
  include Doorkeeper::Helpers::Filter

  doorkeeper_for :all
end
```

### Route Constraints and other integrations

You can leverage the `Doorkeeper.authenticate` facade to easily extract a
`Doorkeeper::OAuth::Token` based on the current request. You can then ensure
that token is still good, find its associated `#resource_owner_id`, etc.

```ruby
module Constraint
  class Authenticated

    def matches?(request)
      token = Doorkeeper.authenticate(request)
      token && token.accessible?
    end

  end
end
```

For more information about integration and other integrations, check out [the
related wiki
page](https://github.com/doorkeeper-gem/doorkeeper/wiki/ActionController::Metal-with-doorkeeper).

### Access Token Scopes

You can also require the access token to have specific scopes in certain
actions:

First configure the scopes in `initializers/doorkeeper.rb`

```ruby
Doorkeeper.configure do
  default_scopes :public # if no scope was requested, this will be the default
  optional_scopes :admin, :write
end
```

And in your controllers:

```ruby
class Api::V1::ProductsController < Api::V1::ApiController
  doorkeeper_for :index, :show,    :scopes => [:public]
  doorkeeper_for :update, :create, :scopes => [:admin, :write]
end
```

For a more detailed explanation about scopes usage, check out the related
[page in the
wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes).

### Authenticated resource owner

If you want to return data based on the current resource owner, in other
words, the access token owner, you may want to define a method in your
controller that returns the resource owner instance:

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

In this example, we're returning the credentials (`me.json`) of the access
token owner.

### Applications list

By default, the applications list (`/oauth/applications`) is public available.
To protect the endpoint you should uncomment these lines:

```ruby
# config/initializers/doorkeeper.rb
Doorkeeper.configure do
  admin_authenticator do |routes|
    Admin.find_by_id(session[:admin_id]) || redirect_to(routes.new_admin_session_url)
  end
end
```

The logic is the same as the `resource_owner_authenticator` block. **Note:**
since the application list is just a scaffold, it's recommended to either
customize the controller used by the list or skip the controller at all. For
more information see the page [in the
wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki/Customizing-routes).

## Other customizations

- [Associate users to OAuth applications (ownership)](https://github.com/doorkeeper-gem/doorkeeper/wiki/Associate-users-to-OAuth-applications-%28ownership%29)
- [CORS - Cross Origin Resource Sharing](https://github.com/doorkeeper-gem/doorkeeper/wiki/%5BCORS%5D-Cross-Origin-Resource-Sharing)

## Upgrading

If you want to upgrade doorkeeper to a new version, check out the [upgrading
notes](https://github.com/doorkeeper-gem/doorkeeper/wiki/Migration-from-old-versions)
and take a look at the
[changelog](https://github.com/doorkeeper-gem/doorkeeper/blob/master/CHANGELOG.md).

## Development

To run the local engine server:

```
rails=3.2.8 orm=active_record bundle install
rails=3.2.8 orm=active_record bundle exec rails server
````

By default, it uses the latest Rails version with ActiveRecord. To run the
tests:

```
rails=3.2.8 orm=active_record bundle exec rake
```

Or you might prefer to run `script/run_all` to integrate against all ORMs.

## Contributing

Want to contribute and don't know where to start? Check out [features we're
missing](https://github.com/doorkeeper-gem/doorkeeper/wiki/Supported-Features),
create [example
apps](https://github.com/doorkeeper-gem/doorkeeper/wiki/Example-Applications),
integrate the gem with your app and let us know!

Also, check out our [contributing guidelines
page](https://github.com/doorkeeper-gem/doorkeeper/wiki/Contributing).

## Other resources

### Wiki

You can find everything about doorkeeper in our [wiki
here](https://github.com/doorkeeper-gem/doorkeeper/wiki).

### Live demo

Check out this [live demo](http://doorkeeper-provider.herokuapp.com) hosted on
heroku. For more demos check out [the
wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki/Example-Applications).

### Screencast

Check out this screencast from [railscasts.com](http://railscasts.com/): [#353
OAuth with
Doorkeeper](http://railscasts.com/episodes/353-oauth-with-doorkeeper)

### Client applications

After you set up the provider, you may want to create a client application to
test the integration. Check out these [client
examples](https://github.com/doorkeeper-gem/doorkeeper/wiki/Example-Applications)
in our wiki or follow this [tutorial
here](https://github.com/doorkeeper-gem/doorkeeper/wiki/Testing-your-provider-with-OAuth2-gem).

### Contributors

Thanks to all our [awesome
contributors](https://github.com/doorkeeper-gem/doorkeeper/contributors)!

### License

MIT License. Copyright 2011 Applicake.
[http://applicake.com](http://applicake.com)

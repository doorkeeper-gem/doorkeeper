# Doorkeeper — awesome OAuth 2 provider for your Rails / Grape app.

[![Gem Version](https://badge.fury.io/rb/doorkeeper.svg)](https://rubygems.org/gems/doorkeeper)
[![CI](https://github.com/doorkeeper-gem/doorkeeper/actions/workflows/ci.yml/badge.svg)](https://github.com/doorkeeper-gem/doorkeeper/actions/workflows/ci.yml)
[![Maintainability](https://qlty.sh/gh/doorkeeper-gem/projects/doorkeeper/maintainability.svg)](https://qlty.sh/gh/doorkeeper-gem/projects/doorkeeper)
[![Coverage Status](https://coveralls.io/repos/github/doorkeeper-gem/doorkeeper/badge.svg?branch=main)](https://coveralls.io/github/doorkeeper-gem/doorkeeper?branch=main)
[![GuardRails badge](https://api.guardrails.io/v2/badges/21183?token=66768ce8f6995814df81f65a2cff40f739f688492704f973e62809e15599bb62)](https://dashboard.guardrails.io/gh/doorkeeper-gem/repos/21183)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-success.svg)](https://dependabot.com)

Doorkeeper is a gem (Rails engine) that makes it easy to introduce OAuth 2 provider
functionality to your Ruby on Rails or Grape application.

Supported features:

- [The OAuth 2.0 Authorization Framework](https://datatracker.ietf.org/doc/html/rfc6749)
  - [Authorization Code Flow](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1)
  - [Access Token Scopes](https://datatracker.ietf.org/doc/html/rfc6749#section-3.3)
  - [Refresh token](https://datatracker.ietf.org/doc/html/rfc6749#section-1.5)
  - [Implicit grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.2)
  - [Resource Owner Password Credentials](https://datatracker.ietf.org/doc/html/rfc6749#section-4.3)
  - [Client Credentials](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)
- [OAuth 2.0 Token Revocation](https://datatracker.ietf.org/doc/html/rfc7009)
- [OAuth 2.0 Token Introspection](https://datatracker.ietf.org/doc/html/rfc7662)
- [OAuth 2.0 Threat Model and Security Considerations](https://datatracker.ietf.org/doc/html/rfc6819)
- [OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252)
- [Proof Key for Code Exchange by OAuth Public Clients](https://datatracker.ietf.org/doc/html/rfc7636)
- [OAuth 2.0 Authorization Server Issuer Identification](https://datatracker.ietf.org/doc/html/rfc9207) — opt-in by setting `issuer`; adds the `iss` parameter to authorization redirects returned to the client
- [Resource Indicators for OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc8707)
- [OAuth Client ID Metadata Documents](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-client-id-metadata-document) — experimental, opt-in by setting `use_client_id_metadata_documents`; lets a client identify itself with an `https://` URL Doorkeeper fetches its metadata from instead of pre-registering. See the option's notes in the generated initializer before enabling it.

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Documentation](#documentation)
- [Installation](#installation)
  - [Ruby on Rails](#ruby-on-rails)
  - [Grape](#grape)
- [ORMs](#orms)
- [Extensions](#extensions)
- [Database maintenance](#database-maintenance)
- [Resource Indicators](#resource-indicators)
- [Custom Grant Flows](#custom-grant-flows)
- [Custom Client Authentication Methods](#custom-client-authentication-methods)
- [Example Applications](#example-applications)
- [Sponsors](#sponsors)
- [Development](#development)
- [Contributing](#contributing)
- [Contributors](#contributors)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Documentation

This documentation is valid for `main` branch. Please check the documentation for the version of doorkeeper you are using in:
https://github.com/doorkeeper-gem/doorkeeper/releases.

Additionally, other resources can be found on:

- [Guides](https://doorkeeper.gitbook.io/guides/) with how-to get started and configuration documentation
- See the [Wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki) for articles on how to integrate with other solutions
- Screencast from [railscasts.com](http://railscasts.com/): [#353
OAuth with
Doorkeeper](http://railscasts.com/episodes/353-oauth-with-doorkeeper)
- See [upgrade guides](https://github.com/doorkeeper-gem/doorkeeper/wiki/Migration-from-old-versions)
- For general questions, please post on [Stack Overflow](http://stackoverflow.com/questions/tagged/doorkeeper)
- See [SECURITY.md](SECURITY.md) for this project's security disclose
  policy

## Installation

Installation depends on the framework you're using. The first step is to add the following to your Gemfile:

```ruby
gem 'doorkeeper'
```

And run `bundle install`. After this, check out the guide related to the framework you're using.

### Ruby on Rails

Doorkeeper currently supports Ruby on Rails >= 5.0. See the guide [here](https://doorkeeper.gitbook.io/guides/ruby-on-rails/getting-started).

### Grape

Guide for integration with Grape framework can be found [here](https://doorkeeper.gitbook.io/guides/grape/grape).

## ORMs

Doorkeeper supports Active Record by default, but can be configured to work with the following ORMs:

| ORM | Support via |
| :--- | :--- |
| Active Record | by default |
| MongoDB | [doorkeeper-gem/doorkeeper-mongodb](https://github.com/doorkeeper-gem/doorkeeper-mongodb) |
| Sequel | [nbulaj/doorkeeper-sequel](https://github.com/nbulaj/doorkeeper-sequel) |
| Couchbase | [acaprojects/doorkeeper-couchbase](https://github.com/acaprojects/doorkeeper-couchbase) |
| RethinkDB | [aca-labs/doorkeeper-rethinkdb](https://github.com/aca-labs/doorkeeper-rethinkdb) |

## Extensions

Extensions that are not included by default and can be installed separately.

|  | Link |
| :--- | :--- |
| OpenID Connect extension | [doorkeeper-gem/doorkeeper-openid\_connect](https://github.com/doorkeeper-gem/doorkeeper-openid_connect) |
| JWT Token support | [doorkeeper-gem/doorkeeper-jwt](https://github.com/doorkeeper-gem/doorkeeper-jwt) |
| Assertion grant extension | [doorkeeper-gem/doorkeeper-grants\_assertion](https://github.com/doorkeeper-gem/doorkeeper-grants_assertion) |
| I18n translations | [doorkeeper-gem/doorkeeper-i18n](https://github.com/doorkeeper-gem/doorkeeper-i18n) |
| CIBA - Client Initiated Backchannel Authentication Flow extension | [doorkeeper-ciba](https://github.com/autoseg/doorkeeper-ciba) |
| Device Authorization Grant | [doorkeeper-device_authorization_grant](https://github.com/exop-group/doorkeeper-device_authorization_grant) |

## Database maintenance

Doorkeeper does **not** automatically remove expired or revoked tokens and grants. The `oauth_access_tokens` and `oauth_access_grants` tables grow indefinitely and can reach millions of rows if left unmanaged.

Prune them periodically with the bundled rake task:

```bash
bundle exec rake doorkeeper:db:cleanup
```

This deletes expired and revoked access tokens and grants. See the [Rake tasks guide](https://doorkeeper.gitbook.io/guides/internals/rake) for details.

## Resource Indicators

Doorkeeper supports [Resource Indicators for OAuth 2.0 (RFC 8707)](https://datatracker.ietf.org/doc/html/rfc8707), allowing clients to signal which protected resource(s) they intend to access. Tokens are then audience-restricted to those resources.

### Setup

1. Run the generator to add the required `resource` column:

```bash
rails generate doorkeeper:resource_indicators
rails db:migrate
```

2. Configure a validator in your initializer:

```ruby
# config/initializers/doorkeeper.rb
Doorkeeper.configure do
  resource_indicator_validator ->(resource_indicators, client) {
    allowed = %w[https://api.example.com/ https://calendar.example.com/]
    resource_indicators.all? { |r| allowed.include?(r) }
  }
end
```

The callable receives an array of resource URIs and the OAuth client. Return `true` to accept or `false` to reject with `invalid_target`.

### Behavior

- Resource URIs must be absolute and must not contain a fragment component.
- Resource indicators are stored on grants and tokens.
- Token and refresh requests enforce subset restrictions against the original grant.
- Token introspection responses include `aud` when resource indicators are present.
- Grants issued with resource indicators retain their audience restriction even if the validator is later removed from configuration.

### Multiple resources

RFC 8707 uses repeated query parameters (`?resource=…&resource=…`) for multiple values, but Rack collapses repeated keys to the last value. Clients must use the Rails bracket syntax for multiple resource indicators:

```
?resource[]=https://api.example.com/&resource[]=https://calendar.example.com/
```

A single `resource=…` works as-is.

## Custom Grant Flows

Besides the built-in OAuth 2 flows, Doorkeeper can recognize and process any custom grant type through its grant flow registry — including grant types whose names are URNs or URIs, such as the SAML 2.0 bearer assertion grant defined by [RFC 7522](https://www.rfc-editor.org/rfc/rfc7522).

A grant flow bundles a matcher for the `grant_type` parameter with a strategy class that processes the token request. Register it before `Doorkeeper.configure` and enable it by adding its registered name to `grant_flows`:

```ruby
# config/initializers/doorkeeper.rb
Doorkeeper::GrantFlow.register(
  :saml2_bearer,
  grant_type_matches: "urn:ietf:params:oauth:grant-type:saml2-bearer",
  grant_type_strategy: SamlBearer::Strategy,
)

Doorkeeper.configure do
  grant_flows %w[authorization_code saml2_bearer]
  # ...
end
```

Note that `grant_flows` lists the *registered flow name* (`saml2_bearer`), while `grant_type_matches` — a `String` or a `Regexp` — is what the request's `grant_type` parameter is matched against.

The strategy class receives the authorization server as `server` and builds the request object handling the grant:

```ruby
module SamlBearer
  class Strategy < Doorkeeper::Request::Strategy
    delegate :client, :parameters, to: :server

    def request
      @request ||= TokenRequest.new(Doorkeeper.config, client, parameters)
    end
  end
end
```

The request object validates the grant and issues the token. Subclassing `Doorkeeper::OAuth::BaseRequest` provides the response handling, scope calculation and token creation, so only the grant-specific parts remain (per RFC 7522 §2.1 the `assertion` parameter carries a single SAML assertion, base64url-encoded without padding):

```ruby
module SamlBearer
  class TokenRequest < Doorkeeper::OAuth::BaseRequest
    validate :client, error: Doorkeeper::Errors::InvalidClient
    validate :client_supports_grant_flow, error: Doorkeeper::Errors::UnauthorizedClient
    validate :assertion, error: Doorkeeper::Errors::InvalidGrant
    validate :scopes, error: Doorkeeper::Errors::InvalidScope

    attr_reader :client, :parameters, :access_token

    def initialize(server, client, parameters = {})
      @server          = server
      @client          = client
      @parameters      = parameters
      @original_scopes = parameters[:scope]
      @grant_type      = "urn:ietf:params:oauth:grant-type:saml2-bearer"
    end

    private

    def before_successful_response
      find_or_create_access_token(client, resource_owner, scopes, {}, server)
      super
    end

    def assertion
      # Decode and verify the SAML assertion — signature, audience, validity
      # window, etc. — e.g. with the ruby-saml gem. Skipping verification
      # turns the endpoint into a token vending machine for anyone.
      @assertion ||= decode_and_verify_saml(parameters[:assertion])
    end

    def resource_owner
      # Map the assertion's subject to a resource owner.
      @resource_owner ||= User.find_by(email: assertion.name_id)
    end

    def validate_client
      client.present?
    end

    def validate_client_supports_grant_flow
      Doorkeeper.config.allow_grant_flow_for_client?(grant_type, client&.application)
    end

    def validate_assertion
      assertion.present? && resource_owner.present?
    end

    def validate_scopes
      return true if scopes.blank?

      Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
        scope_str: scopes.to_s,
        server_scopes: server.scopes,
        app_scopes: client&.scopes,
        grant_type: grant_type,
      )
    end
  end
end
```

The `client_supports_grant_flow` validation keeps the custom grant subject to the `allow_grant_flow_for_client` configuration option (per-client grant restrictions), just like the built-in flows.

Flows can also handle custom `response_type` values on the authorization endpoint via the `response_type_matches` / `response_type_strategy` options — see the built-in registrations in [`lib/doorkeeper/grant_flow.rb`](lib/doorkeeper/grant_flow.rb) for reference. An extension can also group several flows under one configuration name with `Doorkeeper::GrantFlow.register_alias` (e.g. the OpenID Connect extension registers `implicit_oidc` to expand to multiple response types).

## Custom Client Authentication Methods

Doorkeeper authenticates clients (RFC 6749 §2.3) through a registry of named methods. `client_secret_basic`, `client_secret_post` and `none` are built in, and an application or extension can register additional ones — for instance to keep accepting credentials that a partner integration sends in its own headers.

A method is any object that responds to `matches_request?` and `authenticate`. Register it before `Doorkeeper.configure` and enable it by listing its registered name in `client_authentication`:

```ruby
# config/initializers/doorkeeper.rb
Doorkeeper::ClientAuthentication.register(
  :partner_headers,
  PartnerHeaders::Authentication,
)

Doorkeeper.configure do
  client_authentication %i[client_secret_basic client_secret_post partner_headers none]
  # ...
end
```

The order of `client_authentication` is the order the methods are tried in: the first one whose `matches_request?` returns true handles the request.

`matches_request?` decides whether the request carries this method's credentials, and `authenticate` extracts them into a `Doorkeeper::ClientAuthentication::Credentials` pair (or `nil`):

```ruby
module PartnerHeaders
  class Authentication
    def self.matches_request?(request)
      request.get_header("HTTP_X_CLIENT_ID").present? &&
        request.get_header("HTTP_X_CLIENT_SECRET").present?
    end

    def self.authenticate(request)
      Doorkeeper::ClientAuthentication::Credentials.new(
        request.get_header("HTTP_X_CLIENT_ID"),
        request.get_header("HTTP_X_CLIENT_SECRET"),
      )
    end
  end
end
```

Three things are worth keeping in mind when writing one.

**Keep `matches_request?` as narrow as possible.** RFC 6749 §2.3 forbids a client from using more than one authentication method in a single request, and Doorkeeper enforces that across the whole registry rather than only the enabled methods. A method that matches too broadly therefore collides with a built-in one and the request is answered with `invalid_request`.

**The returned credentials are resolved with `by_uid_and_secret`.** A blank secret resolves only a public (non-confidential) client — that is what the built-in `none` method relies on — while a confidential client is resolved only when the secret matches the registered one.

A method that establishes the client's identity by some other proof, such as a client certificate or a signed assertion, has no registered secret to produce. Return a `VerifiedCredentials` instead: it carries the uid alone and skips the secret comparison, since the proof has already been checked.

```ruby
def self.authenticate(request)
  uid = uid_from_verified_certificate(request)
  return if uid.blank?

  Doorkeeper::ClientAuthentication::VerifiedCredentials.new(uid)
end
```

**Declare the IANA name of the method you implement.** Doorkeeper records which method authenticated a request, so that a caller needing to know *how* a client authenticated does not have to trust each strategy to say so. Expose it as `auth_method_name` — the name as registered with [IANA](https://www.iana.org/assignments/oauth-parameters/oauth-parameters.xhtml#token-endpoint-auth-method), which is how a client naming the method in its metadata would write it, and which need not match the key you registered the strategy under:

```ruby
def self.auth_method_name
  "tls_client_auth"
end
```

This matters when `use_client_id_metadata_documents` is enabled. Such a client's document names the one method it authenticates with, and the draft requires client authentication "of the registered type", so Doorkeeper refuses to authenticate it by any other — including a strategy that declares no name at all. Such clients are also forbidden every method built on a shared secret, and a strategy is taken to be one unless it says otherwise — so a method that verifies the client without a shared secret (mTLS, a signed assertion) has to declare that too before a document may select it:

```ruby
def self.uses_shared_secret?
  false
end
```

Servers that do not enable that option are unaffected by either declaration.

Enabled methods are advertised in the authorization server metadata, so a registered method appears in `token_endpoint_auth_methods_supported` at `/.well-known/oauth-authorization-server` once `client_authentication` lists it — under the `auth_method_name` it declares, or under its registration key when it declares none.

## Example Applications

These applications show how Doorkeeper works and how to integrate with it. Start with the oAuth2 server and use the clients to connect with the server.

| Application | Link |
| :--- | :--- |
| OAuth2 Server with Doorkeeper | [doorkeeper-gem/doorkeeper-provider-app](https://github.com/doorkeeper-gem/doorkeeper-provider-app) |
| Sinatra Client connected to Provider App | [doorkeeper-gem/doorkeeper-sinatra-client](https://github.com/doorkeeper-gem/doorkeeper-sinatra-client) |
| Devise + Omniauth Client | [doorkeeper-gem/doorkeeper-devise-client](https://github.com/doorkeeper-gem/doorkeeper-devise-client) |

You may want to create a client application to
test the integration. Check out these [client
examples](https://github.com/doorkeeper-gem/doorkeeper/wiki/Example-Applications)
in our wiki or follow this [tutorial
here](https://github.com/doorkeeper-gem/doorkeeper/wiki/Testing-your-provider-with-OAuth2-gem).

## Sponsors

[![OpenCollective](https://opencollective.com/doorkeeper-gem/backers/badge.svg)](#backers) 
[![OpenCollective](https://opencollective.com/doorkeeper-gem/sponsors/badge.svg)](#sponsors)

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [[Become a sponsor](https://opencollective.com/doorkeeper-gem#sponsor)]

<a href="https://codecademy.com/about/careers?utm_source=doorkeeper-gem" target="_blank"><img src="https://static-assets.codecademy.com/marketing/codecademy_logo_padded.png"/></a>

> Codecademy supports open source as part of its mission to democratize tech. Come help us build the education the world deserves: [https://codecademy.com/about/careers](https://codecademy.com/about/careers?utm_source=doorkeeper-gem)

<br>

<a href="https://oauth.io/?utm_source=doorkeeper-gem" target="_blank"><img src="https://oauth.io/img/logo_text.png"/></a>

> If you prefer not to deal with the gory details of OAuth 2, need dedicated customer support & consulting, try the cloud-based SaaS version: [https://oauth.io](https://oauth.io/?utm_source=doorkeeper-gem)

<br>

<a href="https://www.wealthsimple.com/?utm_source=doorkeeper-gem" target="_blank"><img src="https://wealthsimple.s3.amazonaws.com/branding/medium-black.svg"/></a>

> Wealthsimple is a financial company on a mission to help everyone achieve financial freedom by providing products and advice that are accessible and affordable. Using smart technology, Wealthsimple takes financial services that are often confusing, opaque and expensive and makes them simple, transparent, and low-cost. See what Investing on Autopilot is all about: [https://www.wealthsimple.com](https://www.wealthsimple.com/?utm_source=doorkeeper-gem)

## Development

To run the local engine server:

```
bundle install
bundle exec rake doorkeeper:server
````

By default, it uses the latest Rails version with ActiveRecord. To run the
tests with a specific Rails version:

```
BUNDLE_GEMFILE=gemfiles/rails_6_0.gemfile bundle exec rake
```

You can also experiment with the changes using `bin/console`. It uses in-memory SQLite database and default
Doorkeeper config, but you can reestablish connection or reconfigure the gem if you need.

## Contributing

Want to contribute and don't know where to start? Check out [features we're
missing](https://github.com/doorkeeper-gem/doorkeeper/wiki/Supported-Features),
create [example
apps](https://github.com/doorkeeper-gem/doorkeeper/wiki/Example-Applications),
integrate the gem with your app and let us know!

Also, check out our [contributing guidelines page](CONTRIBUTING.md).

## Contributors

Thanks to all our [awesome
contributors](https://github.com/doorkeeper-gem/doorkeeper/graphs/contributors)!

<a href="https://github.com/doorkeeper-gem/doorkeeper/graphs/contributors"><img src="https://opencollective.com/doorkeeper-gem/contributors.svg?width=890&button=false" /></a>

## License

MIT License. Created in Applicake. Maintained by the community.

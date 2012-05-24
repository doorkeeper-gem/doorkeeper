# Changelog

## 0.4.0 (unreleased)

- enhancements
  - [#83] Add Resource Owner Password Credentials flow [@jaimeiniesta](https://github.com/jaimeiniesta)
  - [#76] Allow token expiration to be disabled [@mattgreen](https://github.com/mattgreen)
  - [#b6470a] Add Client Credentials flow
- internals
  - [#2ece8d, #f93778] Introduce Client and ErrorResponse classes

## 0.3.4

- Fix attr_accessible for rails 3.2.x

## 0.3.3

- [#86] shrink gem package size

## 0.3.2

- enhancements
  - [#54] Ignore Authorization: headers that are not Bearer [@miyagawa](https://github.com/miyagawa)
  - [#58, #64] Add destroy action to applications endpoint [@jaimeiniesta](https://github.com/jaimeiniesta), [@davidfrey](https://github.com/davidfrey)
  - [#63] TokensController responds with `401 unauthorized` [@jaimeiniesta](https://github.com/jaimeiniesta)
  - [#67, #72] Fix for mass-assignment [@cicloid](https://github.com/cicloid)
- internals
  - [#49] Add Gemnasium status image to README [@laserlemon](https://github.com/laserlemon)
  - [#50] Fix typos [@tomekw](https://github.com/tomekw)
  - [#51] Updated the factory_girl_rails dependency, fix expires_in response which returned a float number instead of integer [@antekpiechnik](https://github.com/antekpiechnik)
  - [#62] Typos, .gitignore [@jaimeiniesta](https://github.com/jaimeiniesta)
  - [#65] Change _path redirections to _url redirections [@jaimeiniesta](https://github.com/jaimeiniesta)
  - [#75] Fix unknown method #authenticate_admin! [@mattgreen](https://github.com/mattgreen)
  - Remove application link in authorized app view

## 0.3.1

- enhancements
  - [#48] Add if, else options to doorkeeper_for
  - Add views generator
- internals
  - Namespace models

## 0.3.0

- enhancements
  - [#17, #31] Add support for client credentials in basic auth header [@GoldsteinTechPartners](https://github.com/GoldsteinTechPartners)
  - [#28] Add indices to migration [@GoldsteinTechPartners](https://github.com/GoldsteinTechPartners)
  - [#29] Allow doorkeeper to run with rails 3.2 [@john-griffin](https://github.com/john-griffin)
  - [#30] Improve client's redirect uri validation [@GoldsteinTechPartners](https://github.com/GoldsteinTechPartners)
  - [#32] Add token (implicit grant) flow [@GoldsteinTechPartners](https://github.com/GoldsteinTechPartners)
  - [#34] Add support for custom unathorized responses [@GoldsteinTechPartners](https://github.com/GoldsteinTechPartners)
  - [#36] Remove repetitions from the Authorised Applications view [@carvil](https://github.com/carvil)
  - When user revoke an application, all tokens for that application are revoked
  - Error messages now can be translated
  - Install generator copies the error messages localization file
- internals
  - Fix deprecation warnings in ActiveSupport::Base64
  - Remove deprecation in doorkeeper_for that handles hash arguments
  - Depends on railties instead of whole rails framework
  - CI now integrates with rails 3.1 and 3.2

## 0.2.0

- enhancements
  - [#4] Add authorized applications endpoint
  - [#5, #11] Add access token scopes
  - [#10] Add access token expiration by default
  - [#9, #12] Add refresh token flow
- internals
  - [#7] Improve configuration options with :default
  - Improve configuration options with :builder
  - Refactor config class
  - Improve coverage of authorization request integration
- bug fixes
  - [#6, #20] Fix access token response headers
  - Fix issue with state parameter
- deprecation
  - deprecate :only and :except options in doorkeeper_for

## 0.1.1

- enhancements
  - [#3] Authorization code must be short lived and single use
  - [#2] Improve views provided by doorkeeper
  - [#1] Skips authorization form if the client has been authorized by the resource owner
  - Improve readme
- bugfixes
  - Fix issue when creating the access token (wrong client id)

## 0.1.0

- Authorization Code flow
- OAuth applications endpoint

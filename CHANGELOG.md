# Changelog

## 0.2.0 (unreleased)

- enhancements
  - [#4] Add authorized applications endpoint
  - [#11] Add access token scopes
  - [#10] Add access token expiration by default
- internals
  - [#7] Improve configuration options with :default
  - Improve configuration options with :builder
  - Refactor config class
  - Improve coverage of authorization request integration
- bug fixes
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

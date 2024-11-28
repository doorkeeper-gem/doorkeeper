# Changelog

See https://github.com/doorkeeper-gem/doorkeeper/wiki/Migration-from-old-versions for
upgrade guides.

User-visible changes worth mentioning.

## main


- [#1690] Consider expires_in when clear expired tokens with StaleRecordsCleaner.
- [#1747] Fix unknown pkce method error when configured

## 5.8.0

- [#1739] Add support for dynamic scopes
- [#1715] Fix token introspection invalid request reason
- [#1714] Fix `Doorkeeper::AccessToken.find_or_create_for` with empty scopes which raises NoMethodError
- [#1712] Add `Pragma: no-cache` to token response
- [#1726] Refactor token introspection class.
- [#1727] Allow to set null secret value for Applications if they are public.
- [#1735] Add `pkce_code_challenge_methods` config option. 

## 5.7.1

- [#1705] Add `force_pkce` option that requires non-confidential clients to use PKCE when requesting an access_token using an authorization code

## 5.7.0

- [#1696] Add missing `#issued_token` method to `OAuth::TokenResponse`
- [#1697] Allow a TokenResponse body to be customized (memoize response body).
- [#1702] Fix bugs for error response in the form_post and error view
- [#1660] Custom access token attributes are now considered when finding matching tokens (fixes #1665).
  Introduce `revoke_previous_client_credentials_token` configuration option.

## 5.6.9

- [#1691] Make new Doorkeeper errors backward compatible with older extensions.

## 5.6.8

- [#1680] Fix handle_auth_errors :raise NotImplementedError

## 5.6.7

- [#1662] Specify uri_redirect validation class explicitly.
- [#1652] Add custom attributes support to token generator.
- [#1667] Pass `client` instead of `grant.application` to `find_or_create_access_token`.
- [#1673] Honor `custom_access_token_attributes` in client credentials grant flow.
- [#1676] Improve AuthorizationsController error response handling
- [#1677] Fix URIHelper.valid_for_authorization? breaking for non url URIs.

## 5.6.6

- [#1644] Update HTTP headers.
- [#1646] Block public clients automatic authorization skip.
- [#1648] Add custom token attributes to Refresh Token Request.
- [#1649] Fixed custom_access_token_attributes related errors.

## 5.6.5

- [#1602] Allow custom data to be stored inside access grants/tokens.
- [#1634] Code refactoring for custom token attributes.
- [#1639] Add grant type validation to avoid Internal Server Error for DELETE /oauth/authorize endpoint.

## 5.6.4

- [#1633] Apply ORM configuration in #to_prepare block to avoid autoloading errors.

## 5.6.3

- [#1622] Drop support for Rubies 2.5 and 2.6
- [#1605] Fix URI validation for Ruby 3.2+.
- [#1625] Exclude endless access tokens from `StaleRecordsCleaner`.
- [#1626] Remove deprecated `active_record_options` config option.
- [#1631] Fix regression with redirect behavior after token lookup optimizations (redirect to app URI when found).
- [#1630] Special case unique index creation for refresh_token on SQL Server.
- [#1627] Lazy evaluate Doorkeeper config when loading files and executing initializers.

## 5.6.2

- [#1604] Fix fetching of the application when custom application_class defined.

## 5.6.1

- [#1593] Add support for Trilogy ActiveRecord adapter.
- [#1597] Add optional support to use the url path for the native authorization code flow. Ports forward [#1143] from 4.4.3
- [#1599] Remove unnecessarily re-fetch of application object when creating an access token.

## 5.6.0

- [#1581] Consider `token_type_hint` when searching for access token in TokensController to avoid extra database calls.

## 5.6.0.rc2

- [#1558] Fixed bug: able to obtain a token with default scopes even if they are not present in the
  application scopes when using client credentials.
- [#1567] Only filter `code` parameter if authorization_code grant flow is enabled.

## 5.6.0.rc1

- [#1551] Change lazy loading for ORM to be Ruby standard autoload.
- [#1552] Remove duplicate IDs on Auth form to improve accessibility.
- [#1542] Improve performance of `Doorkeeper::AccessToken#matching_token_for` using database specific SQL time math.

  **[IMPORTANT]**: API of the `Doorkeeper::AccessToken#matching_token_for` method has changed and now it returns
  only **active** access tokens (previously they were just not revoked). Please remember that the idea of the
  `reuse_access_token` option is to check for existing _active_ token (see configuration option description).

## 5.5.4

- [#1535] Revert changes introduced in #1528 to allow query params in `redirect_uri` as per the spec.

## 5.5.3

- [#1528] Don't allow extra query params in redirect_uri.
- [#1525] I18n source for forbidden token error is now `doorkeeper.errors.messages.forbidden_token.missing_scope`.
- [#1531] Disable `strict-loading` for Doorkeeper models by default.
- [#1532] Add support for Rails 7.

## 5.5.2

- [#1502] Drop support for Ruby 2.4 because of EOL.
- [#1504] Updated the url fragment in the comment for code documentation.
- [#1512] Fix form behavior when response mode is form_post.
- [#1511] Fix that authorization code is returned by fragment if response_mode is fragment.

## 5.5.1

- [#1496] Revoke `old_refresh_token` if `previous_refresh_token` is present.
- [#1495] Fix `respond_to` undefined in API-only mode
- [#1488] Verify client authentication for Resource Owner Password Grant when
  `config.skip_client_authentication_for_password_grant` is set and the client credentials
  are sent in a HTTP Basic auth header.

## 5.5.0

- [#1482] Simplify `TokenInfoController` to be overridable (extract response rendering).
- [#1478] Fix ownership association and Rake tasks when custom models configured.
- [#1477] Respect `ActiveRecord::Base.pluralize_table_names` for Doorkeeper table names.

## 5.5.0.rc2

- [#1473] Enable `Applications` and `AuthorizedApplications` controllers in API mode.

  **[IMPORTANT]** you can still skip these controllers using `skip_controllers` in
    `use_doorkeeper` inside `routes.rb`. Please do it in case you don't need them.

- [#1472] Fix `establish_connection` configuration for custom defined models.
- [#1471] Add support for Ruby 3.0.
- [#1469] Check if `redirect_uri` exists.
- [#1465] Memoize nil doorkeeper_token.
- [#1459] Use built-in Ruby option to remove padding in PKCE code challenge value.
- [#1457] Make owner_id a bigint for newly-generated owner migrations
- [#1452] Empty previous_refresh_token only if present.
- [#1440] Validate empty host in redirect_uri.
- [#1438] Add form post response mode.
- [#1458] Make `config.skip_client_authentication_for_password_grant` a long term configuration option.

## 5.5.0.rc1

- [#1435] Make error response not redirectable when client is unauthorized
- [#1426] Ensure ActiveRecord callbacks are executed on token revocation.
- [#1407] Remove redundant and complex to support helpers froms tests (`should_have_json`, etc).
- [#1416] Don't add introspection route if token introspection completely disabled.
- [#1410] Properly memoize `current_resource_owner` value (consider `nil` and `false` values).
- [#1415] Ignore PKCE params for non-PKCE grants.
- [#1418] Add ability to register custom OAuth Grant Flows.
- [#1420] Require client authentication for Resource Owner Password Grant as stated in OAuth RFC.

  **[IMPORTANT]** you need to create a new OAuth client (`Doorkeeper::Application`) if you didn't
    have it before and use client credentials in HTTP Basic auth if you previously used this grant
    flow without client authentication. To opt out of this you could set the
    `skip_client_authentication_for_password_grant` configuration option to `true`, but note that
    this is in violation of the OAuth spec and represents a security risk.
    All the users of your provider application now need to include client credentials when they use
    this grant flow.

- [#1421] Add Resource Owner instance to authorization hook context for `custom_access_token_expires_in`
  configuration option to allow resource owner based Access Tokens TTL.

## 5.4.0

- [#1404] Make `Doorkeeper::Application#read_attribute_for_serialization` public.

## 5.4.0.rc2

- [#1371] Add `#as_json` method and attributes serialization restriction for Application model.
  Fixes information disclosure vulnerability (CVE-2020-10187).

  **[IMPORTANT]** you need to re-implement `#as_json` method for Doorkeeper Application model
  if you previously used `#to_json` serialization with custom options or attributes or rely on
  JSON response from /oauth/applications.json or /oauth/authorized_applications.json. This change
  is a breaking change which restricts serialized attributes to a very small set of columns.

- [#1395] Fix `NameError: uninitialized constant Doorkeeper::AccessToken` for Rake tasks.
- [#1397] Add `as: :doorkeeper_application` on Doorkeeper application form in order to support
  custom configured application model.
- [#1400] Correctly yield the application instance to `allow_grant_flow_for_client?` config
  option (fixes #1398).
- [#1402] Handle trying authorization with client credentials.

## 5.4.0.rc1
- [#1366] Sets expiry of token generated using `refresh_token` to that of original token. (Fixes #1364)
- [#1354] Add `authorize_resource_owner_for_client` option to authorize the calling user to access an application.
- [#1355] Allow to enable polymorphic Resource Owner association for Access Token & Grant
  models (`use_polymorphic_resource_owner` configuration option).

  **[IMPORTANT]** Review your custom patches or extensions for Doorkeeper internals if you
  have such - since now Doorkeeper passes Resource Owner instance to every objects and not
  just it's ID. See PR description for details.

- [#1356] Remove duplicated scopes from Access Tokens and Grants on attribute assignment.
- [#1357] Fix `Doorkeeper::OAuth::PreAuthorization#as_json` method causing
  `Stack level too deep` error with AMS (fix #1312).
- [#1358] Deprecate `active_record_options` configuration option.
- [#1359] Refactor Doorkeeper configuration options DSL to make it easy to reuse it
  in external extensions.
- [#1360] Increase `matching_token_for` lookup size to 10 000 and make it configurable.
- [#1371] Fix controllers to use valid classes in case Doorkeeper has custom models configured.
- [#1370] Fix revocation response for invalid token and unauthorized requests to conform with RFC 7009 (fixes #1362).

  **[IMPORTANT]** now fully according to RFC 7009 nobody can do a revocation request without `client_id`
  (for public clients) and `client_secret` (for private clients). Please update your apps to include that
  info in the revocation request payload.

- [#1373] Make Doorkeeper routes mapper reusable in extensions.
- [#1374] Revoke and issue client credentials token in a transaction with a row lock.
- [#1384] Add context object with auth/pre_auth and issued_token for authorization hooks.
- [#1387] Add `AccessToken#create_for` and use in `RefreshTokenRequest`.
- [#1392] Fix `enable_polymorphic_resource_owner` migration template to have proper index name.
- [#1393] Improve Applications #show page with more informative data on client secret and scopes.
- [#1394] Use Ruby `autoload` feature to load Doorkeeper files.

## 5.3.3

- [#1404] Backport: Make `Doorkeeper::Application#read_attribute_for_serialization` public.

## 5.3.2

- [#1371] Backport: add `#as_json` method and attributes serialization restriction for Application model.
  Fixes information disclosure vulnerability (CVE-2020-10187).

## 5.3.1

- [#1360] Backport: Increase `matching_token_for` batch lookup size to 10 000 and make it configurable.

## 5.3.0

- [#1339] Validate Resource Owner in `PasswordAccessTokenRequest` against `nil` and `false` values.
- [#1341] Fix `refresh_token_revoked_on_use` with `hash_token_secrets` enabled.
- [#1343] Fix ruby 2.7 kwargs warning in InvalidTokenResponse.
- [#1345] Allow to set custom classes for Doorkeeper models, extract reusable AR mixins.
- [#1346] Refactor `Doorkeeper::Application#to_json` into convenient `#as_json` (fix #1344).
- [#1349] Fix `Doorkeeper::Application` AR associations using an incorrect foreign key name when using a custom class.
- [#1318] Make existing token revocation for client credentials optional and disable it by default.

  **[IMPORTANT]** This is a change compared to the behaviour of version 5.2.
  If you were relying on access tokens being revoked once the same client
  requested a new access token, reenable it with `revoke_previous_client_credentials_token` in Doorkeeper
  initialization file.

## 5.2.6

- [#1404] Backport: Make `Doorkeeper::Application#read_attribute_for_serialization` public.

## 5.2.5

- [#1371] Backport: add `#as_json` method and attributes serialization restriction for Application model.
  Fixes information disclosure vulnerability (CVE-2020-10187).

## 5.2.4

- [#1360] Backport: Increase `matching_token_for` batch lookup size to 10 000 and make it configurable.

## 5.2.3

- [#1334] Remove `application_secret` flash helper and `redirect_to` keyword.
- [#1331] Move redirect_uri_validator to where it is used (`Application` model).
- [#1326] Move response_type check in pre_authorization to a method to be easily to override.
- [#1329] Fix `find_in_batches` order warning.

## 5.2.2

- [#1320] Call configured `authenticate_resource_owner` method once per request.
- [#1315] Allow generation of new secret with `Doorkeeper::Application#renew_secret`.
- [#1309] Allow `Doorkeeper::Application#to_json` to work without arguments.

## 5.2.1

- [#1308] Fix flash types for `api_only` mode (no flashes for `ActionController::API`).
- [#1306] Fix interpolation of `missing_param` I18n.

## 5.2.0

- [#1305] Make `Doorkeeper::ApplicationController` to inherit from `ActionController::API` in cases
  when `api_mode` enabled (fixes #1302).

## 5.2.0.rc3

- [#1298] Slice strong params so doesn't error with Rails forms.
- [#1300] Limiting access to attributes of pre_authorization.
- [#1296] Adding client_id to strong parameters.

  **[IMPORTANT]** `Doorkeeper::Server#client_via_uid` was removed.

- [#1293] Move ar specific redirect uri validator to ar orm directory.
- [#1288] Allow to pass attributes to the `Doorkeeper::OAuth::PreAuthorization#as_json` method to customize
  the PreAuthorization response.
- [#1286] Add ability to customize grant flows per application (OAuth client) (#1245 , #1207)
- [#1283] Allow to customize base class for `Doorkeeper::ApplicationMetalController` (new configuration
  option called `base_metal_controller` (fix #1273).
- [#1277] Prevent requested scope be empty on authorization request, handle and add description for invalid request.

## 5.2.0.rc2

- [#1270] Find matching tokens in batches for `reuse_access_token` option (fix #1193).
- [#1271] Reintroduce existing token revocation for client credentials.

  **[IMPORTANT]** If you rely on being able to fetch multiple access tokens from the same
  client using client credentials flow, you should skip to version 5.3, where this behaviour
  is deactivated by default.

- [#1269] Update initializer template documentation.
- [#1266] Use strong parameters within pre-authorization.
- [#1264] Add :before_successful_authorization and :after_successful_authorization hooks in TokensController
- [#1263] Response properly when introspection fails and fix configurations's user guide.

## 5.2.0.rc1

- [#1260], [#1262] Improve Token Introspection configuration option (access to tokens, client).
- [#1257] Add constraint configuration when using client authentication on introspection endpoint.
- [#1252] Returning `unauthorized` when the revocation of the token should not be performed due to wrong permissions.
- [#1249] Specify case sensitive uniqueness to remove Rails 6 deprecation message
- [#1248] Display the Application Secret in HTML after creating a new application even when `hash_application_secrets` is used.
- [#1248] Return the unhashed Application Secret in the JSON response after creating new application even when `hash_application_secrets` is used.
- [#1238] Better support for native app with support for custom scheme and localhost redirection.

## 5.1.2

- [#1404] Backport: Make `Doorkeeper::Application#read_attribute_for_serialization` public.

## 5.1.1

- [#1371] Backport: add `#as_json` method and attributes serialization restriction for Application model.
  Fixes information disclosure vulnerability (CVE-2020-10187).

## 5.1.0

- [#1243] Add nil check operator in token checking at token introspection.
- [#1241] Explaining foreign key options for resource owner in a single place
- [#1237] Allow to set blank redirect URI if Doorkeeper configured to use redirect URI-less grant flows.
- [#1234] Fix `StaleRecordsCleaner` to properly work with big amount of records.
- [#1228] Allow to explicitly set non-expiring tokens in `custom_access_token_expires_in` configuration
  option using `Float::INFINITY` return value.
- [#1224] Do not try to store token if not found by fallback hashing strategy.
- [#1223] Update Hound/Rubocop rules, correct Doorkeeper codebase to follow style-guides.
- [#1220] Drop Rails 4.2 & Ruby < 2.4 support.

## 5.1.0.rc2

- [#1208] Unify hashing implementation into secret storing strategies

  **[IMPORTANT]** If you have been using the master branch of doorkeeper with bcrypt in your Gemfile.lock,
  your application secrets have been hashed using BCrypt. To restore this behavior, use the initializer option
  `hash_application_secrets using: 'Doorkeeper::SecretStoring::BCrypt`.

- [#1216] Add nil check to `expires_at` method.
- [#1215] Fix deprecates for Rails 6.
- [#1214] Scopes field accepts array.
- [#1209] Fix tokens validation for Token Introspection request.
- [#1202] Use correct HTTP status codes for error responses.

  **[IMPORTANT]**: this change might break your application if you were relying on the previous
  401 status codes, this is now a 400 by default, or a 401 for `invalid_client` and `invalid_token` errors.

- [#1201] Fix custom TTL block `client` parameter to always be an `Doorkeeper::Application` instance.

  **[IMPORTANT]**: those who defined `custom_access_token_expires_in` configuration option need to check
  their block implementation: if you are using `oauth_client.application` to get `Doorkeeper::Application`
  instance, then you need to replace it with just `oauth_client`.

- [#1200] Increase default Doorkeeper access token value complexity (`urlsafe_base64` instead of just `hex`)
  matching RFC6749/RFC6750.

  **[IMPORTANT]**: this change have possible side-effects in case you have custom database constraints for
  access token value, application secrets, refresh tokens or you patched Doorkeeper models and introduced
  token value validations, or you are using database with case-insensitive WHERE clause like MySQL
  (you can face some collisions). Before this change access token value matched `[a-f0-9]` regex, and now
  it matches `[a-zA-Z0-9\-_]`. In case you have such restrictions and your don't use custom token generator
  please change configuration option `default_generator_method` to `:hex`.

- [#1195] Allow to customize Token Introspection response (fixes #1194).
- [#1189] Option to set `token_reuse_limit`.
- [#1191] Try to load bcrypt for hashing of application secrets, but add fallback.

## 5.1.0.rc1

- [#1188] Use `params` instead of `request.POST` in tokens controller (fixes #1183).
- [#1182] Fix loopback IP redirect URIs to conform with RFC8252, p. 7.3 (fixes #1170).
- [#1179] Authorization Code Grant Flow without client id returns invalid_client error.
- [#1177] Allow to limit `scopes` for certain `grant_types`
- [#1176] Fix test factory support for `factory_bot_rails`
- [#1175] Internal refactor: use `scopes_string` inside `scopes`.
- [#1168] Allow optional hashing of tokens and secrets.
- [#1164] Fix error when `root_path` is not defined.
- [#1162] Fix `enforce_content_type` for requests without body.

## 5.0.3

- [#1371] Backport: add `#as_json` method and attributes serialization restriction for Application model.
  Fixes information disclosure vulnerability (CVE-2020-10187).

## 5.0.2

- [#1158] Fix initializer template: change `handle_auth_errors` option
- [#1157] Remove redundant index from migration template.

## 5.0.1

- [#1154] Refactor `StaleRecordsCleaner` to be ORM agnostic.
- [#1152] Fix migration template: change resource owner data type from integer to Rails generic `references`
- [#1151] Fix Refresh Token strategy: add proper validation of client credentials both for Public & Private clients.
- [#1149] Fix for `URIChecker#valid_for_authorization?` false negative when query is blank, but `?` present.
- [#1140] Allow rendering custom errors from exceptions (issue #844). Originally opened as [#944].
- [#1138] Revert regression bug (check for token expiration in Authorizations controller so authorization
  triggers every time)

## 5.0.0

- [#1127] Change the token_type initials of the Banner Token to uppercase to comply with the RFC6750 specification.

## 5.0.0.rc2

- [#1122] Fix AuthorizationsController#new error response to be in JSON format
- [#1119] Fix token revocation for OAuth apps using "implicit" grant flow
- [#1116] `AccessGrant`s will now be revoked along with `AccessToken`s when
  hitting the `AuthorizedApplicationController#destroy` route.
- [#1114] Make token info endpoint's attributes consistent with token creation
- [#1108] Simple formatting of callback URLs when listing oauth applications
- [#1106] Restrict access to AdminController with 'Forbidden 403' if admin_authenticator is not
  configured by developers.

## 5.0.0.rc1

- [#1103] Allow customizing use_refresh_token
- [#1089] Removed enable_pkce_without_secret configuration option
- [#1102] Expiration time based on scopes
- [#1099] All the configuration variables in `Doorkeeper.configuration` now
  always return a non-nil value (`true` or `false`)
- [#1099] ORM / Query optimization: Do not revoke the refresh token if it is not enabled
  in `doorkeeper.rb`
- [#996] Expiration Time Base On Grant Type
- [#997] Allow PKCE authorization_code flow as specified in RFC7636
- [#907] Fix lookup for matching tokens in certain edge-cases
- [#992] Add API option to use Doorkeeper without management views for API only
  Rails applications (`api_only`)
- [#1045] Validate redirect_uri as the native URI when making authorization code requests
- [#1048] Remove deprecated `Doorkeeper#configured?`, `Doorkeeper#database_installed?`, and
  `Doorkeeper#installed?` method
- [#1031] Allow public clients to authenticate without `client_secret`. Define an app as
  either public or private/confidential

  **[IMPORTANT]**: all the applications (clients) now are considered as private by default.
  You need to manually change `confidential` column to `false` if you are using public clients,
  in other case your mobile (or other) applications will not be able to authorize.
  See [#1142](https://github.com/doorkeeper-gem/doorkeeper/issues/1142) for more details.

- [#1010] Add configuration to enforce configured scopes (`default_scopes` and
  `optional_scopes`) for applications
- [#1060] Ensure that the native redirect_uri parameter matches with redirect_uri of the client
- [#1064] Add :before_successful_authorization and :after_successful_authorization hooks
- [#1069] Upgrade Bootstrap to 4 for Admin
- [#1068] Add rake task to cleanup databases that can become large over time
- [#1072] AuthorizationsController: Memoize strategy.authorize_response result to enable
  subclasses to use the response object.
- [#1075] Call `before_successful_authorization` and `after_successful_authorization` hooks
  on `create` action as well as `new`
- [#1082] Fix #916: remember routes mapping and use it required places (fix error with
  customized Token Info route).
- [#1086, #1088] Fix bug with receiving default scopes in the token even if they are
  not present in the application scopes (use scopes intersection).
- [#1076] Add config to enforce content type to application/x-www-form-urlencoded
- Fix bug with `force_ssl_in_redirect_uri` when it breaks existing applications with an
  SSL redirect_uri.

## 4.4.3

- [#1143] Adds a config option `opt_out_native_route_change` to opt out of the breaking api
  changed introduced in https://github.com/doorkeeper-gem/doorkeeper/pull/1003

## 4.4.2

- [#1130] Backport fix for native redirect_uri from 5.x.

## 4.4.1

- [#1127] Backport token type to comply with the RFC6750 specification.
- [#1125] Backport Quote surround I18n yes/no keys

## 4.4.0

- [#1120] Backport security fix from 5.x for token revocation when using public clients

  **[IMPORTANT]**: all the applications (clients) now are considered as private by default.
  You need to manually change `confidential` column to `false` if you are using public clients,
  in other case your mobile (or other) applications will not be able to authorize.
  See [#1142](https://github.com/doorkeeper-gem/doorkeeper/issues/1142) for more details.

## 4.3.2

- [#1053] Support authorizing with query params in the request `redirect_uri` if explicitly present in app's `Application#redirect_uri`

## 4.3.1

- Remove `BaseRecord` and introduce additional concern for ordering methods to fix
  braking changes for Doorkeeper models.
- [#1032] Refactor BaseRequest callbacks into configurable lambdas
- [#1040] Clear mixins from ActiveRecord DSL and save only overridable API. It
  allows to use this mixins in Doorkeeper ORM extensions with minimum code boilerplate.

## 4.3.0

- [#976] Fix to invalidate the second redirect URI when the first URI is the native URI
- [#1035] Allow `Application#redirect_uri=` to handle array of URIs.
- [#1036] Allow to forbid Application redirect URI's with specific rules.
- [#1029] Deprecate `order_method` and introduce `ordered_by`. Sort applications
  by `created_at` in index action.
- [#1033] Allow Doorkeeper configuration option #force_ssl_in_redirect_uri to be a callable object.
- Fix Grape integration & add specs for it
- [#913] Deferred ORM (ActiveRecord) models loading
- [#943] Fix Access Token token generation when certain errors occur in custom token generators
- [#1026] Implement RFC7662 - OAuth 2.0 Token Introspection
- [#985] Generate valid migration files for Rails >= 5
- [#972] Replace Struct subclassing with block-form initialization
- [#1003] Use URL query param to pass through native redirect auth code so automated apps can find it.

  **[IMPORTANT]**: Previously authorization code response route was `/oauth/authorize/<code>`,
  now it is `oauth/authorize/native?code=<code>` (in order to help applications to automatically find the code value).

- [#868] `Scopes#&` and `Scopes#+` now take an array or any other enumerable
  object.
- [#1019] Remove translation not in use: `invalid_resource_owner`.
- Use Ruby 2 hash style syntax (min required Ruby version = 2.1)
- [#948] Make Scopes.<=> work with any "other" value.
- [#974] Redirect URI is checked without query params within AuthorizationCodeRequest.
- [#1004] More explicit help text for `native_redirect_uri`.
- [#1023] Update Ruby versions and test against 2.5.0 on Travis CI.
- [#1024] Migrate from FactoryGirl to FactoryBot.
- [#1025] Improve documentation for adding foreign keys
- [#1028] Make it possible to have composite strategy names.

## 4.2.6

- [#970] Escape certain attributes in authorization forms.

## 4.2.5

- [#936] Deprecate `Doorkeeper#configured?`, `Doorkeeper#database_installed?`, and
  `Doorkeeper#installed?`
- [#909] Add `InvalidTokenResponse#reason` reader method to allow read the kind
  of invalid token error.
- [#928] Test against more recent Ruby versions
- Small refactorings within the codebase
- [#921] Switch to Appraisal, and test against Rails master
- [#892] Add minimum Ruby version requirement

## 4.2.0

- Security fix: Address CVE-2016-6582, implement token revocation according to
  spec (tokens might not be revoked if client follows the spec).
- [#873] Add hooks to Doorkeeper::ApplicationMetalController
- [#871] Allow downstream users to better utilize doorkeeper spec factories by
  eliminating name conflict on `:user` factory.

## 4.1.0

- [#845] Allow customising the `Doorkeeper::ApplicationController` base
  controller

## 4.0.0

- [#834] Fix AssetNotPrecompiled error with Sprockets 4
- [#843] Revert "Fix validation error messages"
- [#847] Specify Null option to timestamps

## 4.0.0.rc4

- [#777] Add support for public client in password grant flow
- [#823] Make configuration and specs ORM independent
- [#745] Add created_at timestamp to token generation options
- [#838] Drop `Application#scopes` generator and warning, introduced for
  upgrading doorkeeper from v2 to v3.
- [#801] Fix Rails 5 warning messages
- Test against Rails 5 RC1

## 4.0.0.rc3

- [#769] Revoke refresh token on access token use. To make use of the new config
  add `previous_refresh_token` column to `oauth_access_tokens`:

  ```
  rails generate doorkeeper:previous_refresh_token
  ```

- [#811] Toughen parameters filter with exact match
- [#813] Applications admin bugfix
- [#799] Fix Ruby Warnings
- Drop `attr_accessible` from models

### Backward incompatible changes

- [#730] Force all timezones to use UTC to prevent comparison issues.
- [#802] Remove `config.i18n.fallbacks` from engine

## 4.0.0.rc2

- Fix optional belongs_to for Rails 5
- Fix Ruby warnings

## 4.0.0.rc1

### Backward incompatible changes

- Drops support for Rails 4.1 and earlier
- Drops support for Ruby 2.0
- [#778] Bug fix: use the remaining time that a token is still valid when
  building the redirect URI for the implicit grant flow

### Other changes

- [#771] Validation error messages fixes
- Adds foreign key constraints in generated migrations between tokens and
  grants, and applications
- Support Rails 5

## 3.1.0

- [#736] Existing valid tokens are now reused in client_credentials flow
- [#749] Allow user to raise authorization error with custom messages.
  Under `resource_owner_authenticator` block a user can
  `raise Doorkeeper::Errors::DoorkeeperError.new('custom_message')`
- [#762] Check doesn’t abort the actual migration, so it runs
- [#722] `doorkeeper_forbidden_render_options` now supports returning a 404 by
  specifying `respond_not_found_when_forbidden: true` in the
  `doorkeeper_forbidden_render_options` method.
- [#734] Simplify and remove duplication in request strategy classes

## 3.0.1

- [#712] Wrap exchange of grant token for access token and access token refresh
  in transactions
- [#704] Allow applications scopes to be mass assigned
- [#707] Fixed order of Mixin inclusion and table_name configuration in models
- [#712] Wrap access token and refresh grants in transactions
- Adds JRuby support
- Specs, views and documentation adjustments

## 3.0.0

### Other changes

- [#693] Updates `en.yml`.

## 3.0.0 (rc2)

### Backward incompatible changes

- [#678] Change application-specific scopes to take precedence over server-wide
  scopes. This removes the previous behavior where the intersection between
  application and server scopes was used.

### Other changes

- [#671] Fixes `NoMethodError - undefined method 'getlocal'` when calling
  the /oauth/token path. Switch from using a DateTime object to update
  AR to using a Time object. (Issue #668)
- [#677] Support editing application-specific scopes via the standard forms
- [#682] Pass error hash to Grape `error!`
- [#683] Generate application secret/UID if fields are blank strings

## 3.0.0 (rc1)

### Backward incompatible changes

- [#648] Extracts mongodb ORMs to
  https://github.com/doorkeeper-gem/doorkeeper-mongodb. If you use ActiveRecord
  you don’t need to do any change, otherwise you will need to install the new
  plugin.
- [#665] `doorkeeper_unauthorized_render_options(error:)` and
  `doorkeeper_forbidden_render_options(error:)` now accept `error` keyword
  argument.

### Removed deprecations

- Removes `doorkeeper_for` deprecation notice.
- Remove `applications.scopes` upgrade notice.

## 2.2.2

- [#541] Fixed `undefined method attr_accessible` problem on Rails 4
  (happens only when ProtectedAttributes gem is used) in #599

## 2.2.1

- [#636] `custom_access_token_expires_in` bugfixes
- [#641] syntax error fix (Issue #612)
- [#633] Send extra details to Custom Token Generator
- [#628] Refactor: improve orm adapters to ease extension
- [#637] Upgrade to rspec to 3.2

## 2.2.0 - 2015-04-19

- [#611] Allow custom access token generators to be used
- [#632] Properly fallback to `default_scopes` when no scope is specified
- [#622] Clarify that there is a logical OR between scopes for authorizing
- [#635] Upgrade to rspec 3
- [#627] i18n fallbacks to english
- Moved CHANGELOG to NEWS.md

## 2.1.4 - 2015-03-27

- [#595] HTTP spec: Add `scope` for refresh token scope param
- [#596] Limit scopes in app scopes for client credentials
- [#567] Add Grape helpers for easier integration with Grape framework
- [#606] Add custom access token expiration support for Client Credentials flow

## 2.1.3 - 2015-03-01

- [#588] Fixes scopes_match? bug that skipped authorization form in some cases

## 2.1.2 - 2015-02-25

- [#574] Remove unused update authorization route.
- [#576] Filter out sensitive parameters from logs.
- [#582] The Authorization HTTP header fields are now case insensitive.
- [#583] Database connection bugfix in certain scenarios.
- Testing improvements

## 2.1.1 - 2015-02-06

- Remove `wildcard_redirect_url` option
- [#481] Customize token flow OAuth expirations with a config lambda
- [#568] TokensController: Memoize strategy.authorize_response result to enable
  subclasses to use the response object.
- [#571] Fix database initialization issues in some configurations.
- Documentation improvements

## 2.1.0 - 2015-01-13

- [#540] Include `created_at` in response.
- [#538] Check application-level scopes in client_credentials and password flow.
- [5596227] Check application scopes in AccessToken when present. Fixes a bug in
  doorkeeper 2.0.0 and 2.0.1 referring to application specific scopes.
- [#534] Internationalizes doorkeeper views.
- [#545] Ensure there is a connection to the database before checking for
  missing columns
- [#546] Use `Doorkeeper::` prefix when referencing `Application` to avoid
  possible application model name conflict.
- [#538] Test with Rails ~> 4.2.

### Potentially backward incompatible changes

- Enable by default `authorization_code` and `client_credentials` grant flows.
  Disables implicit and password grant flows by default.
- [#510, #544, 722113f] Revoked refresh token response bugfix.

## 2.0.1 - 2014-12-17

- [#525, #526, #527] Fix `ActiveRecord::NoDatabaseError` on gem load.

## 2.0.0 - 2014-12-16

### Backward incompatible changes

- [#448] Removes `doorkeeper_for` helper. Now we use
  `before_action :doorkeeper_authorize!`.
- [#469] Allow client applications to restrict the set of allowable scopes.
  Fixes #317. `oauth_applications` relation needs a new `scopes` string column,
  non nullable, which defaults to an empty string. To add the column run:

  ```
  rails generate doorkeeper:application_scopes
  ```

  If you’d rather do it by hand, your ActiveRecord migration should contain:

  ```ruby
  add_column :oauth_applications, :scopes, :string, null: false, default: ‘’
  ```

### Removed deprecations

- Removes `test_redirect_uri` option. It is now called `native_redirect_uri`.
- [#446] Removes `mount Doorkeeper::Engine`. Now we use `use_doorkeeper`.

### Others

- [#484] Performance improvement - avoid performing order_by when not required.
- [#450] When password is invalid in Password Credentials Grant, Doorkeeper
  returned 'invalid_resource_owner' instead of 'invalid_grant', as the spec
  declares. Fixes #444.
- [#452] Allows `revoked_at` to be set in the future, for future expiry.
  Rationale: https://github.com/doorkeeper-gem/doorkeeper/pull/452#issuecomment-51431459
- [#480] For Implicit grant flow, access tokens can now be reused. Fixes #421.
- [#491] Reworks of @jasl's #454 and #478. ORM refactor that allows doorkeeper
  to be extended more easily with unsupported ORMs. It also marks the boundaries
  between shared model code and ORM specifics inside of the gem.
- [#496] Tests with Rails 4.2.
- [#489] Adds `force_ssl_in_redirect_uri` to force the usage of the HTTPS
  protocol in non-native redirect uris.
- [#516] SECURITY: Adds `protect_from_forgery` to `Doorkeeper::ApplicationController`
- [#518] Fix random failures in mongodb.

---

## 1.4.2 - 2015-03-02

- [#576] Filter out sensitive parameters from logs

## 1.4.1 - 2014-12-17

- [#516] SECURITY: Adds `protect_from_forgery` to `Doorkeeper::ApplicationController`

## 1.4.0 - 2014-07-31

- internals
  - [#427] Adds specs expectations.
  - [#428] Error response refactor.
  - [#417] Moves token validation into Access Token class.
  - [#439] Removes redundant module includes.
  - [#443] TokensController and TokenInfoController inherit from ActionController::Metal
- bug
  - [#418] fixes #243, requests with insufficient scope now respond 403 instead
    of 401. (API change)
  - [#438] fixes #398, native redirect for implicit token grant bug.
  - [#440] namespace fixes
- enhancements
  - [#432] Keeps query parameters

## 1.3.1 - 2014-07-06

- enhancements
  - [#405] Adds facade to more easily get the token from a request in a route
    constraint.
  - [#415] Extend Doorkeeper TokenResponse with an `after_successful_response`
    callback that allows handling of `response` object.
- internals
  - [#409] Deprecates `test_redirect_uri` in favor of `native_redirect_uri`.
    See discussion in: [#351].
  - [#411] Clean rspec deprecations. General test improvements.
  - [#412] rspec line width can go longer than 80 (hound CI config).
- bug
  - [#413] fixes #340, routing scope is now taken into account in redirect.
  - [#401] and [#425] application is not required any longer for access_token.

## 1.3.0 - 2014-05-23

- enhancements
  - [#387] Adds reuse_access_token configuration option.

## 1.2.0 - 2014-05-02

- enhancements
  - [#376] Allow users to enable basic header authorization for access tokens.
  - [#374] Token revocation implementation [RFC 7009]
  - [#295] Only enable specific grant flows.
- internals
  - [#381] Locale source fix.
  - [#380] Renames `errors_for` to `doorkeeper_errors_for`.
  - [#390] Style adjustments in accordance with Ruby Style Guide form
    Thoughtbot.

## 1.1.0 - 2014-03-29

- enhancements
  - [#336] mongoid4 support.
  - [#372] Allow users to set ActiveRecord table_name_prefix/suffix options
- internals
  - [#343] separate OAuth's admin and user end-point to different layouts, upgrade theme to Bootstrap 3.1.
  - [#348] Move render_options in filter after `@error` has been set

## 1.0.0 - 2014-01-13

- bug (spec)
  - [#228] token response `expires_in` value is now in seconds, relative to
    request time
  - [#296] client is optional for password grant type.
  - [#319] If client credentials are present on password grant type they are validated
  - [#326] If client credentials are present in refresh token they are validated
  - [#326] If authenticated client does not match original client that
    obtained a refresh token it responds `invalid_grant` instead of
    `invalid_client`. Previous usage was invalid according to Section 5.2 of
    the spec.
  - [#329] access tokens' `scopes` string wa being compared against
    `default_scopes` symbols, always unauthorizing.
  - [#318] Include "WWW-Authenticate" header with Unauthorized responses
- enhancements
  - [#293] Adds ActionController::Instrumentation in TokensController
  - [#298] Support for multiple redirect_uris added.
  - [#313] `AccessToken.revoke_all_for` actually revokes all non-revoked
    tokens for an application/owner instead of deleting them.
  - [#333] Rails 4.1 support
- internals
  - Removes jQuery dependency [fixes #300][pr #312 is related]
  - [#294] Client uid and secret will be generated only if not present.
  - [#316] Test warnings addressed.
  - [#338] Rspec 3 syntax.

---

## 0.7.4 - 2013-12-01

- bug
  - Symbols instead of strings for user input.

## 0.7.3 - 2013-10-04

- enhancements
  - [#204] Allow to overwrite scope in routes
- internals
  - Returns only present keys in Token Response (may imply a backwards
    incompatible change). https://github.com/doorkeeper-gem/doorkeeper/issues/220
- bug
  - [#290] Support for Rails 4 when 'protected_attributes' gem is present.

## 0.7.2 - 2013-09-11

- enhancements
  - [#272] Allow issuing multiple access_tokens for one user/application for multiple devices
  - [#170] Increase length of allowed redirect URIs
  - [#239] Do not try to load unavailable Request class for the current phase.
  - [#273] Relax jquery-rails gem dependency

## 0.7.1 - 2013-08-30

- bug
  - [#269] Rails 3.2 raised `ActiveModel::MassAssignmentSecurity::Error`.

## 0.7.0 - 2013-08-21

- enhancements
  - [#229] Rails 4!
- internals
  - [#203] Changing table name to be specific in column_names_with_table
  - [#215] README update
  - [#227] Use Rails.config.paths["config/routes"] instead of assuming "config/routes.rb" exists
  - [#262] Add jquery as gem dependency
  - [#263] Add a configuration for ActiveRecord.establish_connection
  - Deprecation and Ruby warnings (PRs merged outside of GitHub).

## 0.6.7 - 2013-01-13

- internals
  - [#188] Add IDs to the show views for integration testing [@egtann](https://github.com/egtann)

## 0.6.6 - 2013-01-04

- enhancements
  - [#187] Raise error if configuration is not set

## 0.6.5 - 2012-12-26

- enhancements
  - [#184] Vendor the Bootstrap CSS [@tylerhunt](https://github.com/tylerhunt)

## 0.6.4 - 2012-12-15

- bug
  - [#180] Add localization to authorized_applications destroy notice [@aalvarado](https://github.com/aalvarado)

## 0.6.3 - 2012-12-07

- bugfixes
  - [#163] Error response content-type header should be application/json [@ggayan](https://github.com/ggayan)
  - [#175] Make token.expires_in_seconds return nil when expires_in is nil [@miyagawa](https://github.com/miyagawa)
- enhancements
  - [#166, #172, #174] Behavior to automatically authorize based on a configured proc
- internals
  - [#168] Using expectation syntax for controller specs [@rdsoze](https://github.com/rdsoze)

## 0.6.2 - 2012-11-10

- bugfixes
  - [#162] Remove ownership columns from base migration template [@rdsoze](https://github.com/rdsoze)

## 0.6.1 - 2012-11-07

- bugfixes
  - [#160] Removed |routes| argument from initializer authenticator blocks
- documentation
  - [#160] Fixed description of context of authenticator blocks

## 0.6.0 - 2012-11-05

- enhancements
  - Mongoid `orm` configuration accepts only :mongoid2 or :mongoid3
  - Authorization endpoint does not redirect in #new action anymore. It wasn't specified by OAuth spec
  - TokensController now inherits from ActionController::Metal. There might be performance upgrades
  - Add link to authorization in Applications scaffold
  - [#116] MongoMapper support [@carols10cents](https://github.com/carols10cents)
  - [#122] Mongoid3 support [@petergoldstein](https://github.com/petergoldstein)
  - [#150] Introduce test redirect uri for applications
- bugfixes
  - [#157] Response token status should be `:ok`, not `:success` [@theycallmeswift](https://github.com/theycallmeswift)
  - [#159] Remove ActionView::Base.field_error_proc override (fixes #145)
- internals
  - Update development dependencies
  - Several refactorings
  - Rails/ORM are easily swichable with env vars (rails and orm)
  - Travis now tests against Mongoid v2

## 0.5.0 - 2012-10-20

Official support for rubinius was removed.

- enhancements
  - Configure the way access token is retrieved from request (default to bearer header)
  - Authorization Code expiration time is now configurable
  - Add support for mongoid
  - [#78, #128, #137, #138] Application Ownership
  - [#92] Allow users to skip controllers
  - [#99] Remove deprecated warnings for data-\* attributes [@towerhe](https://github.com/towerhe)
  - [#101] Return existing access_token for PasswordAccessTokenRequest [@benoist](https://github.com/benoist)
  - [#104] Changed access token scopes example code to default_scopes and optional_scopes [@amkirwan](https://github.com/amkirwan)
  - [#107] Fix typos in initializer
  - [#123] i18n for validator, flash messages [@petergoldstein](https://github.com/petergoldstein)
  - [#140] ActiveRecord is the default value for the ORM [@petergoldstein](https://github.com/petergoldstein)
- internals
  - [#112, #120] Replacing update_attribute with update_column to eliminate deprecation warnings [@rmoriz](https://github.com/rmoriz), [@petergoldstein](https://github.com/petergoldstein)
  - [#121] Updating all development dependencies to recent versions. [@petergoldstein](https://github.com/petergoldstein)
  - [#144] Adding MongoDB dependency to .travis.yml [@petergoldstein](https://github.com/petergoldstein)
  - [#143] Displays errors for unconfigured error messages [@timgaleckas](https://github.com/timgaleckas)
- bugfixes
  - [#102] Not returning 401 when access token generation fails [@cslew](https://github.com/cslew)
  - [#125] Doorkeeper is using ActiveRecord version of as_json in ORM agnostic code [@petergoldstein](https://github.com/petergoldstein)
  - [#142] Prevent double submission of password based authentication [@bdurand](https://github.com/bdurand)
- documentation
  - [#141] Add rack-cors middleware to readme [@gottfrois](https://github.com/gottfrois)

## 0.4.2 - 2012-06-05

- bugfixes:
  - [#94] Uninitialized Constant in Password Flow

## 0.4.1 - 2012-06-02

- enhancements:
  - Backport: Move doorkeeper_for extension to Filter helper

## 0.4.0 - 2012-05-26

- deprecation
  - Deprecate authorization_scopes
- database changes
  - AccessToken#resource_owner_id is not nullable
- enhancements
  - [#83] Add Resource Owner Password Credentials flow [@jaimeiniesta](https://github.com/jaimeiniesta)
  - [#76] Allow token expiration to be disabled [@mattgreen](https://github.com/mattgreen)
  - [#89] Configure the way client credentials are retrieved from request
  - [#b6470a] Add Client Credentials flow
- internals
  - [#2ece8d, #f93778] Introduce Client and ErrorResponse classes

## 0.3.4 - 2012-05-24

- Fix attr_accessible for rails 3.2.x

## 0.3.3 - 2012-05-07

- [#86] shrink gem package size

## 0.3.2 - 2012-04-29

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
  - [#65] Change \_path redirections to \_url redirections [@jaimeiniesta](https://github.com/jaimeiniesta)
  - [#75] Fix unknown method #authenticate_admin! [@mattgreen](https://github.com/mattgreen)
  - Remove application link in authorized app view

## 0.3.1 - 2012-02-17

- enhancements
  - [#48] Add if, else options to doorkeeper_for
  - Add views generator
- internals
  - Namespace models

## 0.3.0 - 2012-02-11

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

## 0.2.0 - 2011-12-17

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

## 0.1.1 - 2011-11-30

- enhancements
  - [#3] Authorization code must be short lived and single use
  - [#2] Improve views provided by doorkeeper
  - [#1] Skips authorization form if the client has been authorized by the resource owner
  - Improve readme
- bugfixes
  - Fix issue when creating the access token (wrong client id)

## 0.1.0 - 2011-11-25

- Authorization Code flow
- OAuth applications endpoint

---
name: security-review
description: Verify that code changes do not introduce OAuth security vulnerabilities. Use when modifying token handling, client authentication, scope validation, redirect URI checks, secret comparison, or grant flows in Doorkeeper.
---

# Security Review

When implementing or reviewing changes to Doorkeeper, use this skill to verify that changes do not introduce security vulnerabilities. Doorkeeper is an OAuth 2 provider library — security is the primary constraint.

## Constant-Time Comparisons

All comparisons of secrets MUST use `ActiveSupport::SecurityUtils.secure_compare` or equivalent, never `==`:

- Token values
- Client secrets
- PKCE code challenge verification
- Refresh tokens
- Any cryptographic digest comparison

**Check:** grep for `==` near variables named `token`, `secret`, `code_challenge`, `refresh_token`. If found, replace with `secure_compare`.

**Reference:** The codebase already uses `secure_compare` in `lib/doorkeeper/secret_storing/base.rb`. Follow that pattern.

## Token Leakage Prevention

Tokens and secrets must never appear in:
- Log output (Rails parameter filtering should exclude them)
- Error response bodies (beyond what RFC 6749 requires)
- URL query parameters for sensitive values (except where RFC requires, e.g., authorization codes)
- Exception messages that might be captured by error reporters

**Check:** Doorkeeper registers `Doorkeeper.setup_filter_parameters` (in `lib/doorkeeper.rb`) which adds `client_secret`, `authentication_token`, `access_token`, and `refresh_token` to `Rails.application.config.filter_parameters`, plus `code` when the `authorization_code` grant flow is enabled. Verify any newly-introduced sensitive parameter is covered by that list.

## Redirect URI Validation (RFC 6749 §3.1.2, RFC 8252 §7)

- Redirect URIs must be compared using exact string matching
- Exception: loopback redirects (127.0.0.1, [::1]) allow port variation per RFC 8252 §7.3
- Fragment components (`#`) are forbidden
- Relative URIs are forbidden
- The `urn:ietf:wg:oauth:2.0:oob` redirect is special-cased

**Reference:** `lib/doorkeeper/oauth/helpers/uri_checker.rb` and `lib/doorkeeper/orm/active_record/redirect_uri_validator.rb`

## Client Authentication (RFC 6749 §2.3)

- A client MUST NOT use more than one authentication method per request
- The codebase enforces this via `Doorkeeper::Request.validate_client_authentication!` — ensure new auth methods participate in this check
- Confidential clients must always authenticate; public clients use `none`
- `by_uid_and_secret` must be the resolution path — don't bypass it

**Reference:** `lib/doorkeeper/client_authentication/` and `lib/doorkeeper/request.rb`

## Grant Code Single-Use (RFC 6749 §4.1.2)

- Authorization codes MUST be single-use
- If a code is presented twice, all tokens issued from that code must be revoked
- Race conditions are handled via database locking (`lock!`)

**Reference:** `lib/doorkeeper/oauth/authorization_code_request.rb` — `InvalidGrantReuse` handling

## Scope Validation

- Requested scopes must be a subset of configured server scopes
- Per-application scopes further restrict what a client can request
- `scopes_by_grant_type` can restrict scopes per flow
- Dynamic scopes (if enabled) must still match the configured delimiter pattern

**Reference:** `lib/doorkeeper/oauth/helpers/scope_checker.rb`

## PKCE (RFC 7636)

- When `force_pkce` is true, `code_challenge` is mandatory
- S256 is the recommended (and often required) challenge method
- Code verifier comparison must use the correct transform (SHA256 + base64url for S256, plain for plain)
- Note: the codebase currently uses `==` for PKCE comparison — this is a known issue

## Input Validation

- All user-supplied parameters must be validated before use
- `grant_type`, `response_type`, `response_mode` must match registered values
- Token endpoint enforces `application/x-www-form-urlencoded` content type (when `enforce_content_type` is enabled)
- Multiple values for `scope` in the same request must be rejected at the authorization endpoint

## Revocation (RFC 7009)

- Token revocation should return 200 even for invalid tokens (to avoid information leakage)
- Revoking a refresh token should also revoke associated access tokens
- Client authentication is required for revocation (default behavior)

## Patterns to Avoid

```ruby
# BAD: String comparison on secrets
token == stored_token

# GOOD: Constant-time comparison
ActiveSupport::SecurityUtils.secure_compare(token, stored_token)

# BAD: Token in error message
raise "Invalid token: #{token}"

# GOOD: Generic error
raise Doorkeeper::Errors::InvalidToken

# BAD: Redirect URI with partial matching
uri.start_with?(registered_uri)

# GOOD: Exact match (already handled by URIChecker)
Doorkeeper::OAuth::Helpers::URIChecker.valid_for_authorization?(uri, registered_uris)

# BAD: Skipping client authentication
# Never bypass validate_client_authentication! for token-endpoint requests

# GOOD: All token requests go through client auth
# Request.client_authentication_method calls validate_client_authentication!(request) internally
Doorkeeper::Request.client_authentication_method(request)
```

## After Making Changes

1. Run security-related specs: `bundle exec rspec spec/requests/flows/ spec/lib/oauth/`
2. Check if Brakeman would flag the change: `gem install brakeman && brakeman --no-pager`
3. Verify no token values appear in test output or logs

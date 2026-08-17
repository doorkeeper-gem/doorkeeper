---
name: rfc-compliance
description: Verify OAuth protocol implementations stay aligned with relevant RFCs. Use when adding or modifying grant flows, token responses, error formats, redirect behavior, introspection, revocation, PKCE, or metadata endpoints in Doorkeeper.
---

# RFC Compliance

When implementing or modifying OAuth protocol behavior in Doorkeeper, use this skill to verify the implementation stays aligned with the relevant RFCs.

## Core RFCs

| RFC | Topic | Key Files |
|-----|-------|-----------|
| 6749 | OAuth 2.0 Framework | `lib/doorkeeper/oauth/`, `app/controllers/doorkeeper/` |
| 6750 | Bearer Token Usage | `lib/doorkeeper/oauth/token.rb`, `lib/doorkeeper/rails/helpers.rb` |
| 7009 | Token Revocation | `app/controllers/doorkeeper/tokens_controller.rb` (revoke action) |
| 7636 | PKCE | `lib/doorkeeper/oauth/pre_authorization.rb`, `lib/doorkeeper/oauth/authorization_code_request.rb` |
| 7662 | Token Introspection | `lib/doorkeeper/oauth/token_introspection.rb` |
| 8252 | OAuth for Native Apps | `lib/doorkeeper/oauth/helpers/uri_checker.rb` (loopback) |
| 9207 | Authorization Server Issuer Identification | `lib/doorkeeper/oauth/code_response.rb` (iss param) |
| 8707 | Resource Indicators | `lib/doorkeeper/oauth/resource_indicator_validator.rb` |

## Error Response Format (RFC 6749 §5.2)

Token endpoint errors MUST include:
- `error` — single ASCII error code (required)
- `error_description` — human-readable description (optional)
- HTTP status codes: 400 for most errors, 401 for invalid client auth

Valid error codes for the token endpoint:
`invalid_request`, `invalid_client`, `invalid_grant`, `unauthorized_client`, `unsupported_grant_type`, `invalid_scope`

**Reference:** `lib/doorkeeper/oauth/error_response.rb`

Authorization endpoint errors that are redirectable include `error`, `error_description`, and `state` in the redirect. Non-redirectable errors (invalid redirect_uri, invalid client_id) MUST NOT redirect — render an error page instead.

**Reference:** `lib/doorkeeper/oauth/pre_authorization.rb` — `redirectable?` logic

## Token Response Format (RFC 6749 §5.1)

Successful token responses MUST include:
- `access_token` — the token value
- `token_type` — "Bearer" (case-insensitive per RFC 6750)
- `expires_in` — lifetime in seconds (recommended)

MAY include:
- `refresh_token`
- `scope` — if different from requested

MUST NOT include:
- `refresh_token` in implicit grant responses

**Reference:** `lib/doorkeeper/oauth/token_response.rb`

## Authorization Code Flow (RFC 6749 §4.1)

1. Authorization request → `PreAuthorization` validates, `Code` issues grant
2. Token request → `AuthorizationCodeRequest` validates grant + issues token

Key constraints:
- Code is single-use (§4.1.2) — revoke tokens on replay
- Code must be bound to client_id and redirect_uri
- Code SHOULD expire in max 10 minutes (configurable via `authorization_code_expires_in`)
- redirect_uri in token request must match the one used in authorization request

## PKCE (RFC 7636)

- `code_challenge_method` defaults to "plain" when omitted (§4.2) — but Doorkeeper intentionally requires it when `code_challenge` is present (secure-by-default deviation)
- S256: `BASE64URL(SHA256(code_verifier))` must equal `code_challenge`
- plain: `code_verifier` must equal `code_challenge`
- `code_verifier` is 43-128 characters from `[A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"`

## Token Introspection (RFC 7662)

- MUST require authentication of the requesting party
- Response for inactive/invalid tokens: `{"active": false}` — no other fields
- Response for active tokens includes: `active`, `scope`, `client_id`, `token_type`, `exp`, `iat`, `sub`, `aud`, `iss`
- Doorkeeper omits `token_type` and `exp` for refresh tokens in introspection responses (these fields are OPTIONAL per §2.2, not prohibited — but they are semantically inapplicable to refresh tokens)

**Reference:** `lib/doorkeeper/oauth/token_introspection.rb`

## Token Revocation (RFC 7009)

- Return 200 OK even for invalid/unknown tokens (§2.1) — prevents token enumeration
- Client authentication is required
- The `token_type_hint` parameter is optional; server must still check both types
- Revoking an access token SHOULD revoke associated refresh token (and vice versa)

**Current known deviation:** Doorkeeper returns 403 when the token belongs to a different client, rather than 200.

## Bearer Token Errors (RFC 6750 §3)

- 401 responses MUST include `WWW-Authenticate: Bearer` header
- Error codes in WWW-Authenticate: `invalid_request`, `invalid_token`, `insufficient_scope`
- 403 for `insufficient_scope`, 401 for `invalid_token`, 400 for `invalid_request`

**Reference:** `lib/doorkeeper/oauth/error_response.rb` — `authenticate_info` method

## Resource Indicators (RFC 8707)

- Resource URIs must be absolute and must not contain a fragment
- Multiple resources use repeated `resource` parameters (Rack limitation: use `resource[]` syntax)
- Tokens are audience-restricted to the declared resources
- Refresh requests enforce subset restriction against original grant

**Reference:** `lib/doorkeeper/oauth/resource_indicator_validator.rb`

## Authorization Server Metadata (RFC 8414)

Served at `/.well-known/oauth-authorization-server`. Must include:
- `issuer` — MUST be identical to the `iss` in authorization responses
- `authorization_endpoint`, `token_endpoint`
- `response_types_supported`, `grant_types_supported`
- `token_endpoint_auth_methods_supported`
- `scopes_supported` (recommended)

**Reference:** `lib/doorkeeper/oauth/metadata_response.rb`

## Implementation Patterns

### Adding a new grant type

1. Create a strategy class in `lib/doorkeeper/request/` extending `Doorkeeper::Request::Strategy`
2. Create a request class in `lib/doorkeeper/oauth/` extending `Doorkeeper::OAuth::BaseRequest`
3. Register with `Doorkeeper::GrantFlow.register` in `lib/doorkeeper/grant_flow.rb`
4. Add to default `grant_flows` if it's a standard flow
5. Add specs in `spec/requests/flows/` and `spec/lib/oauth/`

### Adding a new error code

1. Add to `lib/doorkeeper/errors.rb` as a new class inheriting `BaseResponseError`
2. Add I18n key in `config/locales/en.yml`
3. Map to correct HTTP status in the error class's `#type` method

### Adding a new configuration option

1. Add via `option` DSL in `lib/doorkeeper/config.rb`
2. Add validation in `lib/doorkeeper/config/validations.rb` if needed
3. Document in the initializer template: `lib/generators/doorkeeper/templates/initializer.rb`
4. Add specs in `spec/lib/config_spec.rb`

## Verification

After implementing protocol changes:

1. Run flow specs: `bundle exec rspec spec/requests/flows/`
2. Run endpoint specs: `bundle exec rspec spec/requests/endpoints/`
3. Run OAuth unit specs: `bundle exec rspec spec/lib/oauth/`
4. Verify metadata response: `bundle exec rspec spec/requests/endpoints/metadata_spec.rb`

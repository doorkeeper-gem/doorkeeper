---
name: antipattern-prevention
description: Avoid common Ruby and Rails antipatterns that degrade maintainability and performance. Use when writing new code, reviewing PRs, or refactoring existing code in Doorkeeper.
---

# Antipattern Prevention

When writing or reviewing code in Doorkeeper, use this skill to avoid common antipatterns that degrade maintainability and performance.

## 1. Ruby Iteration Instead of SQL

**Severity:** High

```ruby
# BAD — loads all tokens into memory
AccessToken.all.select { |t| t.expired? }

# GOOD — push to database
# The codebase uses expiration_time_sql for this:
# lib/doorkeeper/models/concerns/expiration_time_sql_math.rb
```

```ruby
# BAD
ids = AccessToken.pluck(:id).select { |id| id > 100 }

# GOOD
AccessToken.where("id > ?", 100).pluck(:id)
```

## 2. Fire and Forget (Missing Error Handling)

**Severity:** High

```ruby
# BAD
def fetch_jwks(uri)
  response = Net::HTTP.get(URI(uri))
  JSON.parse(response)
rescue
  nil
end

# GOOD — use the existing HttpFetcher which handles timeouts and errors
# Reference: lib/doorkeeper/http_fetcher.rb
def fetch_jwks(uri)
  response = http_fetcher.fetch(uri)
  JSON.parse(response)
rescue HttpFetcher::FetchError => e
  Rails.logger.warn("JWKS fetch failed: #{e.message}")
  nil
end
```

## 3. Inaudible Failures (Silent Save)

**Severity:** Medium

```ruby
# BAD — fails silently
token.save

# GOOD — raises on failure
token.save!

# ALSO GOOD — check return value
unless token.save
  handle_error(token.errors)
end
```

## 4. Callback Complexity

**Severity:** High

```ruby
# BAD — hidden side effects
class AccessToken
  after_create :notify_admin, :update_metrics, :send_webhook
end

# GOOD — explicit orchestration in request objects
class AuthorizationCodeRequest
  def before_successful_response
    find_or_create_access_token(...)
    super
  end
end
```

Doorkeeper uses `before_successful_response` / `after_successful_response` hooks — this is the correct pattern.

## 5. Bare Rescue

**Severity:** High

```ruby
# BAD — catches Exception, including SystemExit, Interrupt, NoMemoryError
rescue Exception => e
  nil
end

# BAD — swallows all StandardError subclasses indiscriminately
rescue
  nil
end

# GOOD — specific exception classes
rescue JWT::DecodeError, JWT::ExpiredSignature => e
  handle_jwt_error(e)
end
```

## 6. String Interpolation in SQL

**Severity:** Critical (security)

```ruby
# BAD — SQL injection
where("token = '#{params[:token]}'")

# GOOD — parameterized
where(token: params[:token])
where("token = ?", params[:token])
```

## 7. String Equality on Secrets

**Severity:** Critical (security)

```ruby
# BAD — timing attack
token == stored_token

# GOOD — constant-time
ActiveSupport::SecurityUtils.secure_compare(token, stored_token)
```

## 8. Tight Coupling to ActiveRecord

**Severity:** Medium

Doorkeeper supports multiple ORMs. Protocol logic in `lib/doorkeeper/oauth/` should use the model mixin interface:

```ruby
# BAD — AR-specific in protocol code
AccessToken.where(token: value).lock.first

# GOOD — use mixin method
AccessToken.by_token(value)
```

## 9. Shotgun Surgery

**Severity:** Medium

If adding a new token attribute requires editing 8+ files, consider whether the design is right. The `custom_attributes` pattern shows how to add token attributes generically without shotgun surgery.

## 10. Monolithic Methods

**Severity:** Medium

```ruby
# BAD — one method doing too much
def authorize
  validate_client
  validate_scopes
  validate_redirect_uri
  create_grant
  generate_response
end

# GOOD — Doorkeeper's validation DSL
validate :client,        error: Errors::InvalidClient
validate :redirect_uri,  error: Errors::InvalidRedirectUri
validate :scopes,        error: Errors::InvalidScope
```

## Quick Detection Patterns

```bash
# Bare rescue
grep -rn "rescue$" lib/ app/

# Silent save
grep -rn "\.save$" lib/ app/

# SQL interpolation
grep -rn 'where(".*#\{' lib/ app/

# String equality on secrets
grep -rn '== .*token\|== .*secret\|token.* ==' lib/ app/

# Ruby filtering instead of SQL
grep -rn '\.all\.select\|\.all\.map\|\.all\.each' lib/ app/
```

## Verification

After changes:

1. `bundle exec rubocop` — catches many antipatterns automatically
2. `bundle exec rspec` — ensures behavior hasn't regressed
3. Manual review of the diff for the patterns above

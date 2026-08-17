---
name: code-quality
description: Maintain code health and architecture standards when implementing features or refactoring Doorkeeper. Use when adding new classes, modules, configuration options, or when a file is growing large or complex.
---

# Code Quality & Refactoring

When implementing features or refactoring code in Doorkeeper, use this skill to maintain code health and avoid architectural drift.

## Where New Code Belongs

| Type of code | Location |
|-------------|----------|
| Protocol logic (grant processing, token issuance) | `lib/doorkeeper/oauth/` |
| Request strategy (parsing grant_type → request class) | `lib/doorkeeper/request/` |
| Model behavior (token/grant/application mixins) | `lib/doorkeeper/models/` |
| Model concerns (reusable cross-model behavior) | `lib/doorkeeper/models/concerns/` |
| ORM-specific code (ActiveRecord queries, validations) | `lib/doorkeeper/orm/active_record/` |
| Client authentication methods | `lib/doorkeeper/client_authentication/` |
| Configuration options and validation | `lib/doorkeeper/config.rb`, `lib/doorkeeper/config/` |
| Rails integration (routes, helpers, engine) | `lib/doorkeeper/rails/`, `lib/doorkeeper/engine.rb` |
| Grape integration | `lib/doorkeeper/grape/` |
| Controllers exposed to host apps | `app/controllers/doorkeeper/` |
| Views exposed to host apps | `app/views/doorkeeper/` |
| Generators | `lib/generators/doorkeeper/` |

## Large Files to Watch

Known large files that warrant care when modifying:
- `lib/doorkeeper/config.rb` (~873 lines) — the configuration DSL, complex by necessity
- `lib/doorkeeper/models/access_token_mixin.rb` (~607 lines) — consider if new methods belong in a concern
- `lib/doorkeeper/oauth/pre_authorization.rb` (~264 lines) — validation-heavy, watch for growth
- `lib/doorkeeper/oauth/authorization_code_request.rb` (~249 lines) — dense protocol logic

**When adding to these files:** Consider extracting to a new concern or helper module rather than growing them further. The codebase already uses `lib/doorkeeper/models/concerns/` for model decomposition.

## Configuration Option Pattern

Use the established `option` DSL:

```ruby
# In lib/doorkeeper/config.rb, inside the Builder class:
option :my_new_setting, default: :some_default

# Accessed via:
Doorkeeper.config.my_new_setting
```

Add validation in `lib/doorkeeper/config/validations.rb` if the value has constraints.

## Grant Flow Registration Pattern

```ruby
# In lib/doorkeeper/grant_flow.rb:
Doorkeeper::GrantFlow.register(
  :my_flow,
  grant_type_matches: "my_grant_type",
  grant_type_strategy: Doorkeeper::Request::MyFlow,
)
```

## Client Authentication Method Pattern

```ruby
module Doorkeeper
  module ClientAuthentication
    class MyMethod < Method
      def self.matches_request?(request)
        # return true if this method's credentials are present
      end

      def self.authenticate(request)
        Credentials.new(uid, secret)
      end
    end
  end
end

# Registration:
Doorkeeper::ClientAuthentication.register(:my_method, MyMethod)
```

## Validation DSL

The `validate` DSL in `lib/doorkeeper/validations.rb` is the standard pattern for request validation:

```ruby
class MyRequest < Doorkeeper::OAuth::BaseRequest
  validate :client,   error: Doorkeeper::Errors::InvalidClient
  validate :scopes,   error: Doorkeeper::Errors::InvalidScope

  private

  def validate_client
    client.present?
  end

  def validate_scopes
    # return true/false
  end
end
```

Don't duplicate validation logic in controllers — keep it in request/pre_authorization objects.

## Complexity Guidelines

- **Methods**: Keep under 10 lines. Extract private helpers for clarity.
- **Classes**: Keep under 200 lines. Use concerns for model mixins.
- **Nesting**: Max 2 levels of conditionals. Use guard clauses or early returns.
- **Parameters**: Max 3 positional parameters. Use keyword arguments beyond that.

## Backward Compatibility

Doorkeeper is used by many host applications. Changes must be backward-compatible unless explicitly breaking:

- **New config options**: Always provide a sensible default that preserves existing behavior
- **New database columns**: Always make them optional (nullable) with a migration generator
- **Changed behavior**: Gate behind a config flag when possible
- **Deprecated methods**: Use `ActiveSupport::Deprecation.warn` with a removal version
- **View changes**: Note in UPGRADE.md that hosts with overridden views may need to update

## Verification

After refactoring:

1. Run full spec suite: `bundle exec rake spec`
2. Run RuboCop: `bundle exec rubocop`
3. If you changed public API: check that `spec/dummy/config/initializers/doorkeeper.rb` still works
4. If you extracted code: ensure all original specs still pass without modification

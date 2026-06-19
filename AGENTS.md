# Doorkeeper Codebase Guide for AI Agents

Doorkeeper is a Ruby gem and Rails engine that implements an OAuth 2 provider for Rails and Grape applications.

## Core expectations

- Treat OAuth behavior and security requirements as the primary constraint. Changes should stay aligned with the relevant RFCs, especially RFC 6749, RFC 6819, RFC 7009, RFC 7636, RFC 7662, and RFC 8252 where applicable.
- Prefer compatibility-safe changes. Doorkeeper is a library used by host apps, so avoid breaking public APIs, configuration, routes, token semantics, and view overrides unless the task explicitly requires it.
- Keep both Rails and Grape support in mind when changing shared protocol logic.

## Architecture map

- `lib/doorkeeper.rb` is the main entry point and autoload map.
- `lib/doorkeeper/engine.rb` wires the Rails engine, routes, helpers, asset behavior, and ORM hooks.
- `lib/doorkeeper/oauth/**` contains most protocol-level request, response, token, and authorization logic.
- `lib/doorkeeper/request/**` contains grant/request strategy parsing.
- `lib/doorkeeper/models/**` and `lib/doorkeeper/orm/**` hold model mixins, concerns, and ORM integration.
- `app/controllers/doorkeeper/**` and `app/views/doorkeeper/**` are the engine controllers and UI views exposed to host apps.
- `spec/dummy/` is the embedded Rails app used by request, controller, routing, and integration specs.

## Where to add tests

- Request and endpoint behavior: `spec/requests/**`
- Controller behavior: `spec/controllers/**`
- Model and mixin behavior: `spec/models/**`
- Routing behavior: `spec/routing/**`
- Generator behavior: `spec/generators/**`
- Grape integration: `spec/grape/**`

Reuse the helpers and shared support code under `spec/support/**` instead of introducing duplicate test setup.

## Development workflow

From the repository root:

```bash
bundle install
bundle exec rake spec
bundle exec rubocop
```

Useful targeted commands:

```bash
bundle exec rspec spec/path/to/file_spec.rb
bundle exec rake doorkeeper:server
```

To test against a specific Rails version, use one of the gemfiles that actually exists in `gemfiles/`, for example:

```bash
BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile bundle exec rake spec
```

## Code conventions

- Follow `.rubocop.yml` and `.rubocop_todo.yml`.
- The codebase prefers `# frozen_string_literal: true` and double-quoted strings.
- Keep line length and formatting aligned with RuboCop rather than hand-rolling a different style.
- Preserve existing naming and directory conventions; protocol logic usually belongs in `lib/doorkeeper/**`, not in ad hoc helpers.

## Change guidance

- Make surgical changes with specs close to the behavior you changed.
- When changing engine behavior, check whether the impact also reaches host-app integration through `spec/dummy`.
- When changing protocol or token behavior, look for nearby request, controller, and model specs that should move together.
- Avoid introducing behavior that silently weakens validation, token handling, revocation, scope checks, redirect URI checks, or client authentication.

## Changelog and docs

- For user-visible fixes or features, add an entry under `## main` in `CHANGELOG.md`.
- Match the existing changelog style when a PR number is known: `- [#1234] Brief description`
- Update user-facing docs when changing public configuration, supported behavior, generators, or visible views. Start with `README.md`, `UPGRADE.md`, and inline YARD/RDoc comments where relevant.

## Practical reminders

- Prefer existing rake tasks and repository tooling over custom scripts.
- Do not assume examples in older docs are current; verify against files present in this repository.
- If you touch views or translations, check for user override implications and mention them when they affect upgrades.

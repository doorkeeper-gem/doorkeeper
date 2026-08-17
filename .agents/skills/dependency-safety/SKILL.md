---
name: dependency-safety
description: Ensure gems are safe, necessary, and properly constrained when adding, updating, or reviewing dependencies in Doorkeeper. Use when modifying Gemfile, doorkeeper.gemspec, or gemfiles/*.gemfile.
---

# Dependency Safety

When adding, updating, or reviewing dependencies in Doorkeeper, use this skill to ensure gems are safe, necessary, and properly constrained.

## Runtime Dependencies

Doorkeeper has a single runtime dependency: `railties >= 5`. This is intentional — a library should minimize its dependency footprint.

**Before adding a new runtime dependency, ask:**
1. Is the functionality available in Ruby stdlib or Rails already?
2. Can it be an optional dependency (required only if the host app includes it)?
3. Is the gem well-maintained (recent releases, multiple maintainers, good test coverage)?
4. Does it introduce native extensions that complicate installation?

**Prefer optional dependencies** over hard requirements. Example: `jwt` is optional — only needed for `private_key_jwt` client authentication. Check `lib/doorkeeper.rb` for the autoload pattern.

## Checking for Vulnerabilities

```bash
gem install bundler-audit
bundle-audit update
bundle-audit check
```

**Severity mapping:**
- Critical/High CVE in a runtime dependency → must fix immediately
- Critical/High CVE in a dev dependency → fix when convenient (doesn't affect users)
- Medium/Low → assess whether exploitable in Doorkeeper's context

## Version Constraints

### In `doorkeeper.gemspec` (runtime):
- Use permissive constraints: `gem.add_dependency "railties", ">= 5"`
- Doorkeeper supports a wide range of Rails versions — don't over-constrain

### In `Gemfile` (development):
- Pin major versions with pessimistic operator: `gem "rspec-rails", "~> 8.0"`
- `Gemfile.lock` is gitignored (standard for gems — host apps control the resolved versions)

### In `gemfiles/*.gemfile` (CI matrix):
- Each file tests a specific Rails version
- Keep in sync with CI matrix in `.github/workflows/ci.yml`
- Lockfiles (`gemfiles/*.lock`) are also gitignored

## Adding a New Development Dependency

1. Add to `doorkeeper.gemspec` under `add_development_dependency` with a version constraint
2. Add to `Gemfile` if it needs a specific version or group
3. Run `bundle install` to verify resolution succeeds
4. Verify CI still passes across the gemfile matrix

## Adding an Optional Runtime Dependency

Pattern from existing code (`jwt` gem in `lib/doorkeeper/oauth/client_authentication/private_key_jwt.rb`):

```ruby
# Defined as a private class method, called at the point the dependency is needed:
def self.require_jwt!
  require "jwt"
rescue LoadError
  raise LoadError,
        "private_key_jwt client authentication requires the 'jwt' gem (>= 2.7); " \
        "add it to your Gemfile to use this method"
end
private_class_method :require_jwt!
```

The re-raised `LoadError` keeps the diagnosis in server logs rather than leaking it to the OAuth client as an error response. Call the method at the point the dependency is first needed, not at file load time.

## Dependency Health Indicators

| Signal | Good | Concerning |
|--------|------|-----------|
| Last release | < 6 months ago | > 2 years ago |
| Open issues/PRs | Actively triaged | Hundreds unaddressed |
| Maintainers | Multiple | Single individual |
| Downloads | Established usage | Very low |
| License | MIT, Apache, BSD | GPL (viral), None |
| Dependencies | Few, well-known | Deep tree, obscure gems |

## Verification

After dependency changes:

1. `bundle install` succeeds
2. `bundle exec rake spec` passes
3. `bundle-audit check` shows no new vulnerabilities
4. `bundle exec rubocop` passes
5. Check CI gemfiles still resolve

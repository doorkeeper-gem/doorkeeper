---
name: testing
description: Write correct and complete RSpec tests for Doorkeeper. Use when adding specs for new features, writing regression tests for bug fixes, or reviewing test coverage for a change.
---

# Testing

When writing or modifying tests in Doorkeeper, use this skill to ensure tests are correct, complete, and follow project conventions.

## Test Organization

| What you're testing | Where to put the spec |
|--------------------|----------------------|
| OAuth request/response flow (integration) | `spec/requests/flows/` |
| Endpoint behavior (HTTP layer) | `spec/requests/endpoints/` |
| Controller logic (unit) | `spec/controllers/` |
| Model behavior & mixins | `spec/models/doorkeeper/` |
| OAuth protocol logic (unit) | `spec/lib/oauth/` |
| Configuration | `spec/lib/config_spec.rb` |
| Generators | `spec/generators/` |
| Routing | `spec/routing/` |
| Grape integration | `spec/grape/` |

## Spec Conventions

### Style

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::SomeClass do
  describe "#method_name" do
    context "when condition is met" do
      it "does the expected thing" do
        # arrange, act, assert
      end
    end
  end
end
```

### Require Line

All specs use `require "spec_helper"`. The `spec_helper` loads the dummy Rails app, database, factories, and support helpers — it covers both unit and integration needs.

> **Note:** A legacy `spec_helper_integration` file exists but is just a compatibility wrapper around `spec_helper`. Do not use it in new specs.

### Factories

Factories are in `spec/factories.rb`. Use FactoryBot:

```ruby
let(:application) { FactoryBot.create(:application) }
let(:access_token) { FactoryBot.create(:access_token, application: application) }
let(:access_grant) { FactoryBot.create(:access_grant, application: application) }
```

### Helper Methods

Reuse helpers from `spec/support/helpers/`:

- `model_helper.rb` — `client_exists`, `create_resource_owner`, token/grant existence checks
- `request_spec_helper.rb` — `json_response`, `should_have_status`, `url_should_have_param`, `basic_auth_header_for_client`
- `url_helper.rb` — `token_endpoint_url`, `authorization_endpoint_url`, `refresh_token_endpoint_url`
- `config_helper.rb` — `config_is_set` (temporarily override config in a block)
- `authorization_request_helper.rb` — `resource_owner_is_authenticated`, `default_scopes_exist`

### Configuration Changes in Tests

Use `config_is_set` or the Doorkeeper.configure block (resets after each test):

```ruby
before do
  config_is_set(:access_token_expires_in, 100)
end
```

## Test Patterns

### Request/Flow Specs (most important)

```ruby
RSpec.describe "Authorization Code Flow" do
  let(:application) { FactoryBot.create(:application) }
  let(:resource_owner) { User.create!(name: "owner", password: "password") }

  before do
    default_scopes_exist :public
    resource_owner_is_authenticated resource_owner
  end

  it "issues an access token" do
    visit authorization_endpoint_url(client: application)
    click_on "Authorize"

    code = current_params["code"]
    post token_endpoint_url, params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: application.redirect_uri,
      client_id: application.uid,
      client_secret: application.secret,
    }

    expect(response).to have_http_status(:ok)
    expect(json_response["access_token"]).to be_present
  end
end
```

### OAuth Unit Specs

```ruby
RSpec.describe Doorkeeper::OAuth::AuthorizationCodeRequest do
  subject(:request) do
    described_class.new(server, grant, client, params)
  end

  let(:server) do
    double :server,
           access_token_expires_in: 2.days,
           refresh_token_enabled?: false,
           custom_access_token_expires_in: lambda { |context|
             context.grant_type == Doorkeeper::OAuth::AUTHORIZATION_CODE ? 1234 : nil
           }
  end

  let(:resource_owner) { FactoryBot.create :resource_owner }
  let(:grant) do
    FactoryBot.create :access_grant,
                      resource_owner_id: resource_owner.id,
                      resource_owner_type: resource_owner.class.name
  end
  let(:client) { grant.application }
  let(:redirect_uri) { client.redirect_uri }
  let(:params) { { redirect_uri: redirect_uri } }

  before do
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
  end

  describe "#authorize" do
    it "issues a new token for the client" do
      expect { request.authorize }.to change { client.reload.access_tokens.count }.by(1)
    end

    it "revokes the grant" do
      expect { request.authorize }.to(change { grant.reload.accessible? })
    end
  end

  describe "#validate" do
    it "requires the grant to be accessible" do
      grant.revoke
      request.validate
      expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
    end

    it "requires the client" do
      request = described_class.new(server, grant, nil, params)
      request.validate
      expect(request.error).to eq(Doorkeeper::Errors::InvalidClient)
    end
  end
end
```

## What to Test

### For new features:
1. Happy path — the feature works as intended
2. Error cases — invalid input, missing parameters, unauthorized access
3. Edge cases — nil values, empty strings, boundary conditions
4. Configuration interaction — does it respect relevant config options?
5. Backward compatibility — does existing behavior still pass?

### For bug fixes:
1. Regression test — reproduce the exact bug scenario, verify it's fixed
2. Related edge cases — similar situations that might also be affected

### For security fixes:
1. The vulnerability is no longer exploitable
2. The fix doesn't break legitimate use cases
3. Error responses don't leak information

## Common Pitfalls

- **Don't use `sleep`** — use `Timecop.travel` or `Timecop.freeze` instead
- **Don't hardcode token values** — let the system generate them
- **Don't test private methods directly** — test through the public interface
- **Don't forget scopes** — many features are scope-dependent, set them up explicitly
- **Use `Timecop`** for time-dependent tests (expiration, token lifetime)

## Verification

1. Run new specs in isolation: `bundle exec rspec spec/path/to/new_spec.rb`
2. Run the full related directory: `bundle exec rspec spec/lib/oauth/`
3. Run full suite: `bundle exec rake spec`
4. Specs must pass in any order (`--order random`)

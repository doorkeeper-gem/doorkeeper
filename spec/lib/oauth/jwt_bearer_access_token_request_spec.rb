# frozen_string_literal: true

require "spec_helper"
require "openssl"
require "jwt"

RSpec.describe Doorkeeper::OAuth::JwtBearerAccessTokenRequest do
  subject(:request) do
    described_class.new(server, client, assertion, parameters)
  end

  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:issuer) { "https://idp.example.com" }
  let(:audience) { "https://rs.example.com" }
  let(:owner) { FactoryBot.build_stubbed(:resource_owner) }
  let(:application) { FactoryBot.create(:application, confidential: true) }
  let(:client) { Doorkeeper::OAuth::Client.new(application) }
  let(:parameters) { {} }

  let(:server) do
    double(
      :server,
      default_scopes: Doorkeeper::OAuth::Scopes.new,
      access_token_expires_in: 2.hours,
      custom_access_token_expires_in: ->(_context) { nil },
    )
  end

  let(:assertion) { make_assertion }

  def make_assertion(subject: owner.name, client_id: client.uid, alg: "RS256", key: rsa, payload: {})
    now = Time.now.to_i
    claims = {
      "iss" => issuer, "sub" => subject, "aud" => audience, "client_id" => client_id,
      "jti" => SecureRandom.hex(8), "exp" => now + 300, "iat" => now,
    }.merge(payload)
    JWT.encode(claims, key, alg, { typ: "oauth-id-jag+jwt" })
  end

  # NOTE: blocks passed to `jwt_bearer_*` options below must only close over
  # this method's own parameters, never over `let`/instance-variable state
  # directly - `Doorkeeper.configure do ... end` is `instance_eval`'d against
  # the config Builder, so a nested block created while `self` is the Builder
  # keeps the Builder as `self` when later invoked, and `let`/`@ivar` lookups
  # follow `self` at call time (unlike local variables, which are true
  # lexical closures) - referencing a `let` there raises NoMethodError on the
  # Builder instead of resolving to the example.
  def configure_jwt_bearer(resource_owner:, issuer_key:, allow_public_clients: false, authorize: ->(*) { true })
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      grant_flows %w[jwt_bearer]
      jwt_bearer_audience "https://rs.example.com"
      jwt_bearer_trusted_issuer { |iss| iss == "https://idp.example.com" }
      jwt_bearer_issuer_key { |_iss, _kid| issuer_key }
      jwt_bearer_resource_owner_from_assertion { |_iss, _sub, _client| resource_owner }
      jwt_bearer_allow_public_clients allow_public_clients
      jwt_bearer_authorize(&authorize)
    end
  end

  before do
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
    configure_jwt_bearer(resource_owner: owner, issuer_key: rsa.public_key)
  end

  it "issues a new token for the client and resource owner" do
    expect { request.authorize }.to change { Doorkeeper::AccessToken.count }.by(1)

    token = Doorkeeper::AccessToken.last
    expect(token.application_id).to eq(application.id)
    expect(token.resource_owner_id).to eq(owner.id)
  end

  it "never issues a refresh token" do
    request.authorize

    expect(Doorkeeper::AccessToken.last.refresh_token).to be_nil
  end

  it "does not issue a token without a client" do
    request = described_class.new(server, nil, assertion, parameters)

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    expect(request.error).to eq(Doorkeeper::Errors::InvalidClient)
  end

  it "does not issue a token for a public client by default" do
    public_application = FactoryBot.create(:application, confidential: false)
    public_client = Doorkeeper::OAuth::Client.new(public_application)
    request = described_class.new(server, public_client, make_assertion(client_id: public_client.uid), parameters)

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    expect(request.error).to eq(Doorkeeper::Errors::UnauthorizedClient)
  end

  it "issues a token for a public client when jwt_bearer_allow_public_clients is enabled" do
    configure_jwt_bearer(resource_owner: owner, issuer_key: rsa.public_key, allow_public_clients: true)
    public_application = FactoryBot.create(:application, confidential: false)
    public_client = Doorkeeper::OAuth::Client.new(public_application)
    request = described_class.new(server, public_client, make_assertion(client_id: public_client.uid), parameters)

    expect { request.authorize }.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it "does not issue a token when the assertion parameter is missing" do
    request = described_class.new(server, client, nil, parameters)

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    expect(request.error).to eq(Doorkeeper::Errors::InvalidRequest)
  end

  it "does not issue a token when the assertion fails verification" do
    request = described_class.new(server, client, "not-a-jwt", parameters)

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "does not issue a token when no resource owner can be resolved from the assertion" do
    configure_jwt_bearer(resource_owner: nil, issuer_key: rsa.public_key)

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "does not issue a token when jwt_bearer_authorize denies the request" do
    configure_jwt_bearer(resource_owner: owner, issuer_key: rsa.public_key, authorize: ->(*) { false })

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "passes the client, resource owner, scopes and verified claims to jwt_bearer_authorize" do
    seen = {}
    configure_jwt_bearer(
      resource_owner: owner,
      issuer_key: rsa.public_key,
      authorize: lambda do |c, o, s, claims|
        seen[:client] = c
        seen[:owner] = o
        seen[:scopes] = s
        seen[:claims] = claims
        true
      end,
    )

    request.authorize

    expect(seen[:client]).to eq(client)
    expect(seen[:owner]).to eq(owner)
    expect(seen[:claims]["iss"]).to eq(issuer)
  end

  context "with scopes" do
    let(:default_scopes) { Doorkeeper::OAuth::Scopes.from_string("read write") }

    before do
      allow(server).to receive_messages(default_scopes: default_scopes, scopes: default_scopes)
    end

    it "narrows the assertion scope to the requested scope" do
      request = described_class.new(
        server, client, make_assertion(payload: { "scope" => "read write" }), { scope: "read" },
      )

      request.authorize

      expect(Doorkeeper::AccessToken.last.scopes).to eq(Doorkeeper::OAuth::Scopes.from_array(["read"]))
    end

    it "uses the assertion scope as-is when no scope is requested" do
      request = described_class.new(server, client, make_assertion(payload: { "scope" => "read write" }), {})

      request.authorize

      expect(Doorkeeper::AccessToken.last.scopes).to eq(Doorkeeper::OAuth::Scopes.from_array(%w[read write]))
    end

    it "rejects a request for scope broader than the assertion grants" do
      request = described_class.new(
        server, client, make_assertion(payload: { "scope" => "read" }), { scope: "read write" },
      )

      request.authorize

      expect(request.error).to eq(Doorkeeper::Errors::InvalidScope)
    end
  end
end

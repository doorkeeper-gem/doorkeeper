# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::RefreshTokenRequest do
  subject(:request) { described_class.new(server, refresh_token, credentials) }

  let(:server) do
    double :server, access_token_expires_in: 2.minutes, public_client_access_token_expires_in: nil
  end

  let(:refresh_token) do
    FactoryBot.create(:access_token, use_refresh_token: true)
  end

  let(:client) { refresh_token.application }
  let(:credentials) { Doorkeeper::ClientAuthentication::Credentials.new(client.uid, client.secret) }

  before do
    allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(false)
  end

  it "returns :grant_type as refresh_token" do
    expect(request.grant_type).to eq(Doorkeeper::OAuth::REFRESH_TOKEN)
  end

  context "with a polymorphic resource owner" do
    let(:resource_owner) { FactoryBot.create(:doorkeeper_testing_user) }
    let(:application) { FactoryBot.create(:application) }
    let(:refresh_token) do
      PolyAccessToken.create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        use_refresh_token: true,
      )
    end

    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_polymorphic_resource_owner
      end
      stub_const(
        "PolyAccessToken",
        Class.new(ApplicationRecord) do
          include Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken
        end,
      )
      config_is_set(:access_token_class, "PolyAccessToken")
    end

    it "passes the full resource owner on to the new token" do
      described_class.new(server, refresh_token, credentials).authorize

      new_token = PolyAccessToken.order(:id).last
      expect(new_token.id).not_to eq(refresh_token.id)
      expect(new_token.resource_owner).to eq(resource_owner)
    end

    it "passes the full resource owner on to custom_access_token_expires_in" do
      contexts = []
      allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
      allow(server).to receive(:custom_access_token_expires_in).and_return(->(context) { contexts << context && nil })

      described_class.new(server, refresh_token, credentials).authorize

      expect(contexts.map(&:resource_owner)).to eq([resource_owner])
    end
  end

  # https://github.com/doorkeeper-gem/doorkeeper/issues/1730
  describe "revoking the presented refresh token" do
    def keep_previous_access_token
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
        revoke_previous_access_token_on_refresh false
      end
    end

    it "revokes the whole record by default" do
      request.authorize

      expect(refresh_token.reload).to be_revoked
      expect(refresh_token.refresh_token_revoked_at).to be_nil
    end

    it "revokes only the refresh token when the previous access token is kept on refresh" do
      keep_previous_access_token

      request.authorize

      expect(request.error).to be_nil
      expect(refresh_token.reload).to be_refresh_token_revoked
      expect(refresh_token).not_to be_revoked
      expect(refresh_token).to be_accessible
    end

    it "refuses a refresh token that was revoked on its own" do
      refresh_token.update_column(:refresh_token_revoked_at, 1.minute.ago)

      request.validate

      expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
    end

    it "refuses a refresh token revoked on its own between validation and the locked section" do
      keep_previous_access_token
      request.validate
      Doorkeeper::AccessToken.where(id: refresh_token.id).update_all(refresh_token_revoked_at: 1.minute.ago)

      expect { request.authorize }.to raise_error(Doorkeeper::Errors::InvalidGrantReuse)
      expect(Doorkeeper::AccessToken.count).to eq(1)
    end

    it "revokes the whole record when the option is disabled but the column is absent" do
      keep_previous_access_token
      allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_at_supported?).and_return(false)

      request.authorize

      expect(refresh_token.reload).to be_revoked
      expect(refresh_token[:refresh_token_revoked_at]).to be_nil
    end

    # The Sequel and MongoDB adapters ship their own access token mixins,
    # which revoke the refresh token together with its access token.
    context "when the access token model does not implement refresh token revocation" do
      before do
        keep_previous_access_token
        allow(refresh_token).to receive(:respond_to?).and_call_original
        allow(refresh_token).to receive(:respond_to?).with(:refresh_token_revoked?).and_return(false)
        allow(refresh_token).to receive(:respond_to?).with(:revoke_refresh_token).and_return(false)
      end

      it "revokes the whole record" do
        request.authorize

        expect(request.error).to be_nil
        expect(refresh_token.reload).to be_revoked
        expect(refresh_token.refresh_token_revoked_at).to be_nil
      end

      it "refuses a revoked record" do
        refresh_token.revoke

        request.validate

        expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
      end
    end
  end

  it "issues a new token for the client" do
    expect { request.authorize }.to change { client.reload.access_tokens.count }.by(1)
    # #sort_by used for MongoDB ORM extensions for valid ordering
    expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(refresh_token.expires_in)
  end

  context "with custom_access_token_expires_in configured" do
    let(:refresh_token) do
      FactoryBot.create(:access_token, use_refresh_token: true, expires_in: 1234)
    end

    before do
      allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
    end

    # #1364: a lifetime given to the grant the token was first issued with
    # must survive refreshing, so a callable that has nothing to say about
    # the refresh_token grant keeps the TTL of the original token instead of
    # falling back to access_token_expires_in.
    it "issues a new token with the same expiry as the original token when the callable returns nil" do
      allow(server).to receive(:custom_access_token_expires_in).and_return(->(_context) {})

      request.authorize

      # #sort_by used for MongoDB ORM extensions for valid ordering
      expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(1234)
    end

    it "issues a new token with the expiry the callable returns for the refresh_token grant" do
      allow(server).to receive(:custom_access_token_expires_in).and_return(
        ->(context) { context.grant_type == Doorkeeper::OAuth::REFRESH_TOKEN ? 42 : nil },
      )

      request.authorize

      expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(42)
    end

    it "issues a never-expiring token when the callable returns Float::INFINITY" do
      allow(server).to receive(:custom_access_token_expires_in).and_return(->(_context) { Float::INFINITY })

      request.authorize

      expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to be_nil
    end

    it "calls the callable with the refresh token's application, grant type and scopes" do
      contexts = []
      allow(server).to receive(:custom_access_token_expires_in).and_return(->(context) { contexts << context && nil })

      request.authorize

      expect(contexts.size).to eq(1)
      expect(contexts.first).to have_attributes(
        client: client,
        grant_type: Doorkeeper::OAuth::REFRESH_TOKEN,
        scopes: refresh_token.scopes,
        resource_owner: nil,
      )
    end
  end

  context "with public_client_access_token_expires_in configured" do
    let(:refresh_token) do
      FactoryBot.create(:access_token, application: application, use_refresh_token: true, expires_in: nil)
    end

    before do
      allow(server).to receive(:public_client_access_token_expires_in).and_return(600)
    end

    context "when the client is public" do
      let(:application) { FactoryBot.create(:application, confidential: false) }
      let(:credentials) { Doorkeeper::ClientAuthentication::Credentials.new(client.uid, nil) }

      # A refresh chain that started before the ceiling was configured is
      # brought under it on its next refresh; a never-expiring original token
      # does not get to mint never-expiring tokens forever.
      it "caps the expiry of the new token" do
        request.authorize

        expect(request.error).to be_nil
        expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(600)
      end
    end

    context "when the client is confidential" do
      let(:application) { FactoryBot.create(:application, confidential: true) }

      it "keeps the expiry of the original token" do
        request.authorize

        expect(request.error).to be_nil
        expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to be_nil
      end
    end
  end

  it "revokes the previous token" do
    expect { request.authorize }.to change(refresh_token, :revoked?).from(false).to(true)
  end

  it "calls configured request callback methods" do
    expect(Doorkeeper.configuration.before_successful_strategy_response)
      .to receive(:call).with(request).once

    expect(Doorkeeper.configuration.after_successful_strategy_response)
      .to receive(:call).with(request, instance_of(Doorkeeper::OAuth::TokenResponse)).once

    request.authorize
  end

  it "requires the refresh token" do
    request = described_class.new(server, nil, credentials)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidRequest)
    expect(request.missing_param).to eq(:refresh_token)
  end

  it "requires credentials to be valid if provided" do
    credentials = Doorkeeper::ClientAuthentication::Credentials.new("invalid", "invalid")
    request = described_class.new(server, refresh_token, credentials)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidClient)
  end

  it "requires the token's client and current client to match" do
    other_app = FactoryBot.create(:application)
    credentials = Doorkeeper::ClientAuthentication::Credentials.new(other_app.uid, other_app.secret)

    request = described_class.new(server, refresh_token, credentials)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  context "with credentials already authenticated by their client authentication method" do
    let(:credentials) { Doorkeeper::ClientAuthentication::VerifiedCredentials.new(client.uid) }

    it "resolves the client by uid alone" do
      expect(client).to be_confidential

      expect { request.authorize }.to change { client.reload.access_tokens.count }.by(1)
      expect(request.error).to be_nil
    end
  end

  it "rejects revoked tokens" do
    refresh_token.revoke
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "accepts expired tokens" do
    refresh_token.expires_in = -1
    refresh_token.save
    request.validate
    expect(request).to be_valid
  end

  context "when refresh token gets revoked between validation and authorization" do
    before do
      allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
    end

    it "raises InvalidGrantReuse error inside the lock block to prevent race condition" do
      # This test verifies that the InvalidGrantReuse check inside the lock block
      # properly detects when a token has been revoked by a concurrent request.

      # Set up the token to be revoked inside the lock
      allow(refresh_token).to receive(:with_lock) do |&block|
        # Mark token as revoked before executing the block
        allow(refresh_token).to receive(:revoked?).and_return(true)
        block.call
      end

      # Validation should pass (we haven't set up the mock yet)
      expect(request).to be_valid

      # Authorization should raise error when it checks revoked status inside lock
      expect { request.authorize }.to raise_error(Doorkeeper::Errors::InvalidGrantReuse)
    end
  end

  context "when refresh tokens expire on access token use" do
    before do
      allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(true)
    end

    it "issues a new token for the client" do
      expect { request.authorize }.to change { client.reload.access_tokens.count }.by(1)
    end

    it "does not revoke the previous token" do
      request.authorize
      expect(refresh_token).not_to be_revoked
    end

    it "sets the previous refresh token in the new access token" do
      request.authorize
      expect(
        # #sort_by used for MongoDB ORM extensions for valid ordering
        client.access_tokens.max_by(&:created_at).previous_refresh_token,
      ).to eq(refresh_token.refresh_token)
    end

    it "does not lock the previous token model" do
      expect(refresh_token).not_to receive(:lock!)
      request.authorize
    end
  end

  context "with clientless access tokens" do
    subject(:request) { described_class.new(server, refresh_token, nil) }

    let!(:refresh_token) { FactoryBot.create(:clientless_access_token, use_refresh_token: true) }

    it "issues a new token without a client" do
      expect { request.authorize }.to change { Doorkeeper::AccessToken.count }.by(1)
    end
  end

  context "with scopes" do
    subject(:request) { described_class.new(server, refresh_token, credentials, parameters) }

    let(:refresh_token) do
      FactoryBot.create :access_token,
                        use_refresh_token: true,
                        scopes: "public write"
    end
    let(:parameters) { {} }

    it "transfers scopes from the old token to the new token" do
      request.authorize
      expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public write])
    end

    it "reduces scopes to the provided scopes" do
      parameters[:scopes] = "public"
      request.authorize
      expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public])
    end

    it "validates that scopes are included in the original access token" do
      parameters[:scopes] = "public update"

      request.validate
      expect(request.error).to eq(Doorkeeper::Errors::InvalidScope)
    end

    it "uses params[:scope] in favor of scopes if present (valid)" do
      parameters[:scopes] = "public update"
      parameters[:scope] = "public"
      request.authorize
      expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public])
    end

    it "uses params[:scope] in favor of scopes if present (invalid)" do
      parameters[:scopes] = "public"
      parameters[:scope] = "public update"

      request.validate
      expect(request.error).to eq(Doorkeeper::Errors::InvalidScope)
    end

    # RFC 6749 §6: "If a new refresh token is issued, the refresh token scope
    # MUST be identical to that of the refresh token included by the client
    # in the request." Narrowing the access token must not narrow the
    # refresh token issued alongside it.
    it "issues the new refresh token with the presented refresh token's scope when narrowing" do
      parameters[:scope] = "public"
      request.authorize

      new_token = Doorkeeper::AccessToken.last
      expect(new_token.scopes).to eq(%i[public])
      expect(new_token.refresh_token_scopes).to eq(%i[public write])
    end

    context "when the presented refresh token was narrowed on an earlier refresh" do
      let(:refresh_token) do
        FactoryBot.create :access_token,
                          use_refresh_token: true,
                          scopes: "public",
                          refresh_token_scopes: "public write"
      end

      # RFC 6749 §6: an omitted scope "is treated as equal to the scope
      # originally granted by the resource owner", not to the narrowed
      # access token's scope.
      it "restores the granted scope when the scope parameter is omitted" do
        request.authorize

        new_token = Doorkeeper::AccessToken.last
        expect(new_token.scopes).to eq(%i[public write])
        expect(new_token.refresh_token_scopes).to eq(%i[public write])
      end

      it "accepts a requested scope within the granted scope but wider than the access token's" do
        parameters[:scope] = "public write"
        request.authorize

        expect(request.error).to be_nil
        expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public write])
      end

      it "still refuses a scope beyond the granted scope" do
        parameters[:scope] = "public write update"

        request.validate
        expect(request.error).to eq(Doorkeeper::Errors::InvalidScope)
      end

      # Rows that predate the refresh_token_scopes migration carry no
      # granted scope of their own and keep the pre-column behavior.
      it "falls back to the access token scope for a row without a stored refresh token scope" do
        refresh_token.update_column(:refresh_token_scopes, nil)
        parameters[:scope] = "public write"

        request.validate
        expect(request.error).to eq(Doorkeeper::Errors::InvalidScope)
      end
    end

    context "without the refresh_token_scopes column" do
      before do
        allow(Doorkeeper::AccessToken).to receive(:refresh_token_scopes_supported?).and_return(false)
      end

      it "narrows the refresh token along with the access token, as before the column existed" do
        parameters[:scope] = "public"
        request.authorize

        new_token = Doorkeeper::AccessToken.last
        expect(new_token.scopes).to eq(%i[public])
        expect(new_token.refresh_token_scopes).to eq(%i[public])
        expect(new_token[:refresh_token_scopes]).to be_nil
      end
    end

    # The Sequel and MongoDB adapters ship their own access token mixins,
    # which predate the granted-scope API.
    context "when the access token model does not implement refresh_token_scopes" do
      let(:refresh_token) do
        FactoryBot.create :access_token,
                          use_refresh_token: true,
                          scopes: "public",
                          refresh_token_scopes: "public write"
      end

      before do
        allow(refresh_token).to receive(:respond_to?).and_call_original
        allow(refresh_token).to receive(:respond_to?).with(:refresh_token_scopes).and_return(false)
        allow(Doorkeeper::AccessToken).to receive(:respond_to?).and_call_original
        allow(Doorkeeper::AccessToken).to receive(:respond_to?).with(:refresh_token_scopes_supported?).and_return(false)
      end

      it "validates the requested scope against the access token scope, as before the column existed" do
        parameters[:scope] = "public write"

        request.validate
        expect(request.error).to eq(Doorkeeper::Errors::InvalidScope)
      end

      it "issues the refreshed token with the access token scope" do
        request.authorize

        expect(request.error).to be_nil
        expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public])
      end
    end
  end

  context "with dynamic scopes enabled" do
    subject(:request) { described_class.new(server, refresh_token, credentials, parameters) }

    let(:application_scopes) { "public write user:*" }
    let(:application) { FactoryBot.create(:application, scopes: application_scopes) }
    let(:token_scopes) { "public write user:1" }

    let(:refresh_token) do
      FactoryBot.create :access_token,
                        use_refresh_token: true,
                        scopes: token_scopes,
                        application: application
    end

    let(:parameters) { {} }

    before do
      Doorkeeper.configure do
        enable_dynamic_scopes
      end
    end

    it "transfers scopes from the old token to the new token" do
      request.authorize
      expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public write user:1])
    end

    it "returns an error with invalid scope" do
      parameters[:scopes] = "public garbage:*"

      response = request.authorize

      expect(response).to be_a(Doorkeeper::OAuth::ErrorResponse)
      expect(response.status).to eq(:bad_request)
    end

    it "reduces scopes to the dynamic scope" do
      parameters[:scopes] = "user:1"
      request.authorize
      expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[user:1])
    end

    it "reduces scopes to the public scope" do
      parameters[:scopes] = "public"
      request.authorize
      expect(Doorkeeper::AccessToken.last.scopes).to eq(%i[public])
    end
  end
end

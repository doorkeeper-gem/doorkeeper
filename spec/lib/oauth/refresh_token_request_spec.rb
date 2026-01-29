# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::RefreshTokenRequest do
  subject(:request) { described_class.new(server, refresh_token, credentials) }

  let(:server) do
    double :server, access_token_expires_in: 2.minutes
  end

  let(:refresh_token) do
    FactoryBot.create(:access_token, use_refresh_token: true)
  end

  let(:client) { refresh_token.application }
  let(:credentials) { Doorkeeper::OAuth::Client::Credentials.new(client.uid, client.secret) }

  before do
    allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(false)
  end

  it "issues a new token for the client" do
    expect { request.authorize }.to change { client.reload.access_tokens.count }.by(1)
    # #sort_by used for MongoDB ORM extensions for valid ordering
    expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(refresh_token.expires_in)
  end

  it "issues a new token for the client with the same expiry as of original token" do
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
    allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)

    described_class.new(server, refresh_token, credentials).authorize

    # #sort_by used for MongoDB ORM extensions for valid ordering
    expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(refresh_token.expires_in)
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
    credentials = Doorkeeper::OAuth::Client::Credentials.new("invalid", "invalid")
    request = described_class.new(server, refresh_token, credentials)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidClient)
  end

  it "requires the token's client and current client to match" do
    other_app = FactoryBot.create(:application)
    credentials = Doorkeeper::OAuth::Client::Credentials.new(other_app.uid, other_app.secret)

    request = described_class.new(server, refresh_token, credentials)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
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

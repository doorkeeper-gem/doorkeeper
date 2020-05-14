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
    expect(request.error).to eq(:invalid_request)
    expect(request.missing_param).to eq(:refresh_token)
  end

  it "requires credentials to be valid if provided" do
    credentials = Doorkeeper::OAuth::Client::Credentials.new("invalid", "invalid")
    request = described_class.new(server, refresh_token, credentials)
    request.validate
    expect(request.error).to eq(:invalid_client)
  end

  it "requires the token's client and current client to match" do
    other_app = FactoryBot.create(:application)
    credentials = Doorkeeper::OAuth::Client::Credentials.new(other_app.uid, other_app.secret)

    request = described_class.new(server, refresh_token, credentials)
    request.validate
    expect(request.error).to eq(:invalid_grant)
  end

  it "rejects revoked tokens" do
    refresh_token.revoke
    request.validate
    expect(request.error).to eq(:invalid_grant)
  end

  it "accepts expired tokens" do
    refresh_token.expires_in = -1
    refresh_token.save
    request.validate
    expect(request).to be_valid
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
      expect(request.error).to eq(:invalid_scope)
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
      expect(request.error).to eq(:invalid_scope)
    end
  end
end

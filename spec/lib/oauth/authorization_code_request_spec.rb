# frozen_string_literal: true

require "spec_helper"

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

  it "issues a new token for the client" do
    expect do
      request.authorize
    end.to change { client.reload.access_tokens.count }.by(1)

    expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(1234)
  end

  it "issues the token with same grant's scopes" do
    request.authorize
    expect(Doorkeeper::AccessToken.last.scopes).to eq(grant.scopes)
  end

  it "revokes the grant" do
    expect { request.authorize }.to(change { grant.reload.accessible? })
  end

  it "requires the grant to be accessible" do
    grant.revoke
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "requires the grant" do
    request = described_class.new(server, nil, client, params)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "requires the client" do
    request = described_class.new(server, grant, nil, params)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidClient)
  end

  it "requires the redirect_uri" do
    request = described_class.new(server, grant, nil, params.except(:redirect_uri))
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidRequest)
    expect(request.missing_param).to eq(:redirect_uri)
  end

  it "matches the redirect_uri with grant's one" do
    request = described_class.new(server, grant, client, params.merge(redirect_uri: "http://other.com"))
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "matches the client with grant's one" do
    other_client = FactoryBot.create :application
    request = described_class.new(server, grant, other_client, params)
    request.validate
    expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
  end

  it "skips token creation if there is a matching one reusable" do
    scopes = grant.scopes

    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      reuse_access_token
      default_scopes(*scopes)
    end

    FactoryBot.create(
      :access_token,
      application_id: client.id,
      resource_owner_id: grant.resource_owner_id,
      resource_owner_type: grant.resource_owner_type,
      scopes: grant.scopes.to_s,
    )

    expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
  end

  it "creates token if there is a matching one but non reusable" do
    scopes = grant.scopes

    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      reuse_access_token
      default_scopes(*scopes)
    end

    FactoryBot.create(
      :access_token,
      application_id: client.id,
      resource_owner_id: grant.resource_owner_id,
      resource_owner_type: grant.resource_owner_type,
      scopes: grant.scopes.to_s,
    )

    allow_any_instance_of(Doorkeeper::AccessToken).to receive(:reusable?).and_return(false)

    expect { request.authorize }.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  # Regression for #1731: with token reuse enabled and refresh tokens expected,
  # a matching token issued without a refresh token must not be reused - a fresh
  # token is created so the response still carries a refresh token.
  it "creates a token with a refresh token instead of reusing a refresh token-less one" do
    scopes = grant.scopes
    allow(server).to receive(:refresh_token_enabled?).and_return(true)

    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      reuse_access_token
      use_refresh_token
      default_scopes(*scopes)
    end

    FactoryBot.create(
      :access_token,
      application_id: client.id,
      resource_owner_id: grant.resource_owner_id,
      resource_owner_type: grant.resource_owner_type,
      scopes: grant.scopes.to_s,
      use_refresh_token: false,
    )

    response = nil
    expect { response = request.authorize }.to change { Doorkeeper::AccessToken.count }.by(1)
    expect(response.token.plaintext_refresh_token).to be_present
  end

  context "when the authorization code is reused (RFC 6749 §4.1.2)" do
    it "records the issued access token on the grant" do
      request.authorize

      expect(grant.reload.access_token_id).to eq(request.access_token.id)
    end

    it "revokes the token issued for the code when it is exchanged a second time" do
      request.authorize
      issued_token = request.access_token

      replay = described_class.new(server, grant.reload, client, params)
      replay.validate

      expect(replay.error).to eq(Doorkeeper::Errors::InvalidGrant)
      expect(issued_token.reload).to be_revoked
    end

    it "revokes the reused access token when reuse_access_token is enabled" do
      scopes = grant.scopes

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        reuse_access_token
        default_scopes(*scopes)
      end

      existing_token = FactoryBot.create(
        :access_token,
        application_id: client.id,
        resource_owner_id: grant.resource_owner_id,
        resource_owner_type: grant.resource_owner_type,
        scopes: grant.scopes.to_s,
      )

      request.authorize

      expect(grant.reload.access_token_id).to eq(existing_token.id)

      replay = described_class.new(server, grant.reload, client, params)
      replay.validate

      expect(existing_token.reload).to be_revoked
    end

    it "revokes the winning exchange's token when losing the race for the same code" do
      issued_token = FactoryBot.create(
        :access_token,
        application_id: client.id,
        resource_owner_id: grant.resource_owner_id,
        resource_owner_type: grant.resource_owner_type,
      )

      # Simulate a concurrent exchange committing between validation and the
      # row lock: the reload performed by `lock!` reveals the revoked grant
      # with its token linkage.
      allow(grant).to receive(:lock!) do
        grant.update_columns(revoked_at: Time.current, access_token_id: issued_token.id)
      end

      expect { request.authorize }.to raise_error(Doorkeeper::Errors::InvalidGrantReuse)
      expect(issued_token.reload).to be_revoked
    end

    it "only denies the request when the access_token_id column is not available" do
      request.authorize
      issued_token = request.access_token

      allow(Doorkeeper::AccessGrant).to receive(:access_token_revoked_on_reuse?).and_return(false)

      replay = described_class.new(server, grant.reload, client, params)
      replay.validate

      expect(replay.error).to eq(Doorkeeper::Errors::InvalidGrant)
      expect(issued_token.reload).not_to be_revoked
    end

    it "does not revoke the issued token when the replay cannot prove possession of the code" do
      request.authorize
      issued_token = request.access_token

      # A replay that fails the redirect_uri check (RFC 6749 §4.1.3) is
      # denied before the single-use enforcement runs, so it cannot revoke
      # the token issued for the code without proving possession of it.
      replay = described_class.new(
        server, grant.reload, client, redirect_uri: "https://other.example/callback",
      )
      replay.validate

      expect(replay.error).to eq(Doorkeeper::Errors::InvalidGrant)
      expect(issued_token.reload).not_to be_revoked
    end
  end

  it "calls configured request callback methods" do
    expect(Doorkeeper.configuration.before_successful_strategy_response)
      .to receive(:call).with(request).once
    expect(Doorkeeper.configuration.after_successful_strategy_response)
      .to receive(:call).with(request, instance_of(Doorkeeper::OAuth::TokenResponse)).once

    request.authorize
  end

  context "when redirect_uri contains some query params" do
    let(:redirect_uri) { "#{client.redirect_uri}?query=q" }

    it "allows query params" do
      request.validate
      expect(request.error).to be_nil
    end
  end

  context "when redirect_uri is not an URI" do
    let(:redirect_uri) { "123d#!s" }

    it "responds with invalid_grant" do
      request.validate
      expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
    end
  end

  context "when redirect_uri is the native one" do
    let(:redirect_uri) { "urn:ietf:wg:oauth:2.0:oob" }

    it "invalidates when redirect_uri of the grant is not native" do
      request.validate
      expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
    end

    it "validates when redirect_uri of the grant is also native" do
      allow(grant).to receive(:redirect_uri) { redirect_uri }
      request.validate
      expect(request.error).to be_nil
    end
  end

  context "when using PKCE params" do
    context "when force_pkce is enabled" do
      before do
        allow_any_instance_of(Doorkeeper::Config).to receive(:force_pkce?).and_return(true)
      end

      context "when the app is confidential" do
        it "does not issue a token" do
          expect do
            request.authorize
          end.not_to change { client.reload.access_tokens.count }
        end

        it "responds with invalid_request for the missing code_verifier" do
          request.validate
          expect(request.error).to eq(Doorkeeper::Errors::InvalidRequest)
        end
      end

      context "when the app is not confidential" do
        before do
          client.update(confidential: false)
        end

        it "does not issue a token" do
          expect do
            request.authorize
          end.not_to change { client.reload.access_tokens.count }
        end
      end

      context "when the app is missing" do
        it "does not assume non-confidential and forcibly validate pkce params" do
          request = described_class.new(server, grant, nil, params)
          request.validate
          expect(request.error).to eq(Doorkeeper::Errors::InvalidClient)
        end
      end
    end

    context "when PKCE is supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(true)

        grant.code_challenge = "a45a9fea-0676-477e-95b1-a40f72ac3cfb"
        grant.code_challenge_method = "plain"
      end

      it "validates when code_verifier is present" do
        params[:code_verifier] = grant.code_challenge
        request.validate

        expect(request.error).to be_nil
      end

      it "validates when both code_verifier and code_challenge are blank" do
        params[:code_verifier] = grant.code_challenge = ""
        request.validate

        expect(request.error).to be_nil
      end

      it "invalidates when code_verifier is missing" do
        request.validate

        expect(request.error).to eq(Doorkeeper::Errors::InvalidRequest)
        expect(request.missing_param).to eq(:code_verifier)
      end

      it "invalidates when code_verifier is the wrong value" do
        params[:code_verifier] = "foobar"
        request.validate

        expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
      end

      it "invalidates when the stored code challenge method is unknown" do
        grant.code_challenge_method = "unknown"
        params[:code_verifier] = grant.code_challenge
        request.validate

        expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
      end

      context "when PKCE code challenge methods is set to only S256" do
        before do
          Doorkeeper.configure do
            pkce_code_challenge_methods ["S256"]
          end
        end

        it "validates when code_verifier is S256" do
          params[:code_verifier] = grant.code_challenge = "S256"
          request.validate

          expect(request.error).to be_nil
        end

        it "invalidates when code_verifier is plain" do
          params[:code_verifier] = "plain"
          request.validate

          expect(request.error).to eq(Doorkeeper::Errors::InvalidGrant)
        end
      end
    end

    context "when PKCE is not supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(false)
      end

      it "validates when code_verifier is present" do
        params[:code_verifier] = "foobar"
        request.validate

        expect(request.error).to be_nil
      end
    end
  end

  context "when revoke_previous_authorization_code_token is false" do
    before do
      allow(Doorkeeper.config).to receive(:revoke_previous_authorization_code_token?).and_return(false)
    end

    it "does not revoke the previous token" do
      previous_token = FactoryBot.create(
        :access_token,
        application_id: client.id,
        resource_owner_id: grant.resource_owner_id,
        resource_owner_type: grant.resource_owner_type,
        scopes: grant.scopes.to_s,
      )

      expect { request.authorize }.not_to(change { previous_token.reload.revoked_at })
    end
  end

  context "when revoke_previous_authorization_code_token is true" do
    before do
      allow(Doorkeeper.config).to receive(:revoke_previous_authorization_code_token?).and_return(true)
    end

    it "revokes the previous token" do
      previous_token = FactoryBot.create(
        :access_token,
        application_id: client.id,
        resource_owner_id: grant.resource_owner_id,
        resource_owner_type: grant.resource_owner_type,
        scopes: grant.scopes.to_s,
      )

      expect { request.authorize }.to(change { previous_token.reload.revoked_at })
    end
  end
end

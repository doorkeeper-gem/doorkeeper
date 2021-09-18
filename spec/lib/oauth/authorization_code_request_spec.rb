# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::AuthorizationCodeRequest do
  subject(:request) do
    described_class.new(server, grant, client, define_params)
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
    expect(request.error).to eq(:invalid_grant)
  end

  it "requires the grant" do
    request = described_class.new(server, nil, client, define_params)
    request.validate
    expect(request.error).to eq(:invalid_grant)
  end

  it "requires the client" do
    request = described_class.new(server, grant, nil, define_params)
    request.validate
    expect(request.error).to eq(:invalid_client)
  end

  it "matches the client with grant's one" do
    other_client = FactoryBot.create :application
    request = described_class.new(server, grant, other_client, define_params)
    request.validate
    expect(request.error).to eq(:invalid_grant)
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
      request = described_class.new(server, grant, client, define_params(redirect_uri: redirect_uri))
      request.validate
      expect(request.error).to eq(nil)
    end
  end

  context "when redirect_uri is not an URI" do
    let(:redirect_uri) { "123d#!s" }

    it "responds with invalid_grant" do
      request = described_class.new(server, grant, client, define_params(redirect_uri: redirect_uri))
      request.validate
      expect(request.error).to eq(:invalid_grant)
    end
  end

  context "when redirect_uri is the native one" do
    let(:redirect_uri) { "urn:ietf:wg:oauth:2.0:oob" }

    it "invalidates when redirect_uri of the grant is not native" do
      request = described_class.new(server, grant, client, define_params(redirect_uri: redirect_uri))
      request.validate
      expect(request.error).to eq(:invalid_grant)
    end

    it "validates when redirect_uri of the grant is also native" do
      allow(grant).to receive(:redirect_uri) { redirect_uri }
      request = described_class.new(server, grant, client, define_params(redirect_uri: redirect_uri))
      request.validate
      expect(request.error).to eq(nil)
    end
  end

  context "when the grant's redirect_uri is present" do
    it "requires the redirect_uri" do
      request = described_class.new(server, grant, client, define_params(redirect_uri: nil))
      request.validate
      expect(request.error).to eq(:invalid_request)
      expect(request.missing_param).to eq(:redirect_uri)
    end

    it "matches the redirect_uri with grant's one" do
      request = described_class.new(server, grant, client, define_params(redirect_uri: "http://other.com"))
      request.validate
      expect(request.error).to eq(:invalid_grant)
    end
  end

  context "when the grant's redirect_uri is blank" do
    before do
      Doorkeeper.configure do
        redirect_uri_optional_during_authorization true
      end
    end

    let(:grant) do
      FactoryBot.create :access_grant,
                        redirect_uri: nil,
                        resource_owner_id: resource_owner.id,
                        resource_owner_type: resource_owner.class.name
    end

    it "is valid with a blank redirect_uri" do
      request = described_class.new(server, grant, grant.application, define_params(redirect_uri: nil))
      request.valid?
      expect(request.valid?).to eq(true)
    end

    it "is valid if the redirect_uri matches the client's redirect_uri" do
      request = described_class.new(server, grant, grant.application, define_params)
      request.valid?
      expect(request.valid?).to eq(true)
    end

    it "is invalid if the redirect_uri does not match the client's redirect_uri" do
      request = described_class.new(server, grant, grant.application, define_params(redirect_uri: "http://other.com"))
      request.validate
      expect(request.error).to eq(:invalid_grant)
    end
  end

  context "when using PKCE params" do
    context "when PKCE is supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(true)

        grant.code_challenge = "a45a9fea-0676-477e-95b1-a40f72ac3cfb"
        grant.code_challenge_method = "plain"
      end

      it "validates when code_verifier is present" do
        params = define_params(code_verifier: grant.code_challenge)
        request = described_class.new(server, grant, client, params)
        request.validate

        expect(request.error).to eq(nil)
      end

      it "validates when both code_verifier and code_challenge are blank" do
        grant.code_challenge = ""
        params = define_params(code_verifier: grant.code_challenge)
        request = described_class.new(server, grant, client, params)
        request.validate

        expect(request.error).to eq(nil)
      end

      it "invalidates when code_verifier is missing" do
        request.validate

        expect(request.error).to eq(:invalid_request)
        expect(request.missing_param).to eq(:code_verifier)
      end

      it "invalidates when code_verifier is the wrong value" do
        params = define_params(code_verifier: "foobar")
        request = described_class.new(server, grant, client, params)
        request.validate

        expect(request.error).to eq(:invalid_grant)
      end
    end

    context "when PKCE is not supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(false)
      end

      it "validates when code_verifier is present" do
        params = define_params(code_verifier: "foobar")
        request = described_class.new(server, grant, client, params)
        request.validate

        expect(request.error).to be_nil
      end
    end
  end

  def define_params(redirect_uri: client.redirect_uri, **args)
    { redirect_uri: redirect_uri }.merge(args)
  end
end

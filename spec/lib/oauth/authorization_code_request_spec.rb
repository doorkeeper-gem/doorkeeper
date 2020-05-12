# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::AuthorizationCodeRequest do
  subject do
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
      subject.authorize
    end.to change { client.reload.access_tokens.count }.by(1)

    expect(client.reload.access_tokens.max_by(&:created_at).expires_in).to eq(1234)
  end

  it "issues the token with same grant's scopes" do
    subject.authorize
    expect(Doorkeeper::AccessToken.last.scopes).to eq(grant.scopes)
  end

  it "revokes the grant" do
    expect { subject.authorize }.to(change { grant.reload.accessible? })
  end

  it "requires the grant to be accessible" do
    grant.revoke
    subject.validate
    expect(subject.error).to eq(:invalid_grant)
  end

  it "requires the grant" do
    subject = described_class.new(server, nil, client, params)
    subject.validate
    expect(subject.error).to eq(:invalid_grant)
  end

  it "requires the client" do
    subject = described_class.new(server, grant, nil, params)
    subject.validate
    expect(subject.error).to eq(:invalid_client)
  end

  it "requires the redirect_uri" do
    subject = described_class.new(server, grant, nil, params.except(:redirect_uri))
    subject.validate
    expect(subject.error).to eq(:invalid_request)
    expect(subject.missing_param).to eq(:redirect_uri)
  end

  it "invalid code_verifier param because server does not support pkce" do
    allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(false)
    code_verifier = "a45a9fea-0676-477e-95b1-a40f72ac3cfb"
    subject = described_class.new(server, grant, client, params.merge(code_verifier: code_verifier))
    subject.validate
    expect(subject.error).to eq(:invalid_request)
    expect(subject.invalid_request_reason).to eq(:not_support_pkce)
  end

  it "matches the redirect_uri with grant's one" do
    subject = described_class.new(server, grant, client, params.merge(redirect_uri: "http://other.com"))
    subject.validate
    expect(subject.error).to eq(:invalid_grant)
  end

  it "matches the client with grant's one" do
    other_client = FactoryBot.create :application
    subject = described_class.new(server, grant, other_client, params)
    subject.validate
    expect(subject.error).to eq(:invalid_grant)
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

    expect { subject.authorize }.not_to(change { Doorkeeper::AccessToken.count })
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

    expect { subject.authorize }.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it "calls configured request callback methods" do
    expect(Doorkeeper.configuration.before_successful_strategy_response)
      .to receive(:call).with(subject).once
    expect(Doorkeeper.configuration.after_successful_strategy_response)
      .to receive(:call).with(subject, instance_of(Doorkeeper::OAuth::TokenResponse)).once

    subject.authorize
  end

  context "when redirect_uri contains some query params" do
    let(:redirect_uri) { client.redirect_uri + "?query=q" }

    it "compares only host part with grant's redirect_uri" do
      subject.validate
      expect(subject.error).to eq(nil)
    end
  end

  context "when redirect_uri is not an URI" do
    let(:redirect_uri) { "123d#!s" }

    it "responds with invalid_grant" do
      subject.validate
      expect(subject.error).to eq(:invalid_grant)
    end
  end

  context "when redirect_uri is the native one" do
    let(:redirect_uri) { "urn:ietf:wg:oauth:2.0:oob" }

    it "invalidates when redirect_uri of the grant is not native" do
      subject.validate
      expect(subject.error).to eq(:invalid_grant)
    end

    it "validates when redirect_uri of the grant is also native" do
      allow(grant).to receive(:redirect_uri) { redirect_uri }
      subject.validate
      expect(subject.error).to eq(nil)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientCredentials::Creator do
  subject(:creator) { described_class.new }

  let(:client) { FactoryBot.create :application }
  let(:scopes) { Doorkeeper::OAuth::Scopes.from_string("public") }

  before do
    default_scopes_exist :public
  end

  it "creates a new token" do
    expect do
      creator.call(client, scopes)
    end.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it "resolves the application from an authenticated client wrapper" do
    oauth_client = Doorkeeper::OAuth::Client.new(client)

    expect do
      creator.call(oauth_client, scopes)
    end.to change { Doorkeeper::AccessToken.count }.by(1)

    expect(Doorkeeper::AccessToken.last.application).to eq(client)
  end

  context "when reuse_access_token is true" do
    before do
      allow(Doorkeeper.config).to receive(:reuse_access_token).and_return(true)
    end

    context "when expiration is disabled" do
      it "returns the existing valid token" do
        existing_token = creator.call(client, scopes)

        result = creator.call(client, scopes)

        expect(Doorkeeper::AccessToken.count).to eq(1)
        expect(result).to eq(existing_token)
      end
    end

    context "when existing token has not crossed token_reuse_limit" do
      let!(:existing_token) { creator.call(client, scopes, expires_in: 1000) }

      before do
        allow(Doorkeeper.config).to receive(:token_reuse_limit).and_return(50)
        allow_any_instance_of(Doorkeeper::AccessToken).to receive(:expires_in_seconds).and_return(600)
      end

      it "returns the existing valid token" do
        result = creator.call(client, scopes, expires_in: 1000)

        expect(Doorkeeper::AccessToken.count).to eq(1)
        expect(result).to eq(existing_token)
      end

      context "when revoke_previous_client_credentials_token is false" do
        before do
          allow(Doorkeeper.config).to receive(:revoke_previous_client_credentials_token).and_return(false)
        end

        it "does not revoke the existing valid token" do
          creator.call(client, scopes, expires_in: 1000)
          expect(existing_token.reload).not_to be_revoked
        end
      end
    end

    context "when existing token has crossed token_reuse_limit" do
      it "returns a new token" do
        allow(Doorkeeper.config).to receive(:token_reuse_limit).and_return(50)
        existing_token = creator.call(client, scopes, expires_in: 1000)

        allow_any_instance_of(Doorkeeper::AccessToken).to receive(:expires_in_seconds).and_return(400)
        result = creator.call(client, scopes, expires_in: 1000)

        expect(Doorkeeper::AccessToken.count).to eq(2)
        expect(result).not_to eq(existing_token)
      end
    end

    context "when existing token has been expired" do
      it "returns a new token" do
        allow(Doorkeeper.configuration).to receive(:token_reuse_limit).and_return(50)
        existing_token = creator.call(client, scopes, expires_in: 1000)

        allow_any_instance_of(Doorkeeper::AccessToken).to receive(:expired?).and_return(true)
        result = creator.call(client, scopes, expires_in: 1000)

        expect(Doorkeeper::AccessToken.count).to eq(2)
        expect(result).not_to eq(existing_token)
      end
    end

    context "when custom access token attributes are used" do
      before do
        allow(Doorkeeper.config).to receive(:custom_access_token_attributes).and_return([:tenant_name])
      end

      it "does not return an existing token with custom attributes when the request has none" do
        existing_token = creator.call(client, scopes, tenant_name: "Me")

        result = creator.call(client, scopes)

        expect(Doorkeeper::AccessToken.count).to eq(2)
        expect(result).not_to eq(existing_token)
        expect(result.custom_attributes[:tenant_name]).to be_nil
      end

      it "returns an existing token when the custom attributes match" do
        existing_token = creator.call(client, scopes, tenant_name: "Me")

        result = creator.call(client, scopes, tenant_name: "Me")

        expect(Doorkeeper::AccessToken.count).to eq(1)
        expect(result).to eq(existing_token)
      end

      it "returns an existing token without custom attributes when the request has none" do
        existing_token = creator.call(client, scopes)

        result = creator.call(client, scopes)

        expect(Doorkeeper::AccessToken.count).to eq(1)
        expect(result).to eq(existing_token)
      end
    end
  end

  context "when reuse_access_token is false" do
    before do
      allow(Doorkeeper.config).to receive(:reuse_access_token).and_return(false)
    end

    it "returns a new token" do
      existing_token = creator.call(client, scopes)

      result = creator.call(client, scopes)

      expect(Doorkeeper::AccessToken.count).to eq(2)
      expect(result).not_to eq(existing_token)
    end
  end

  context "when revoke_previous_client_credentials_token is true" do
    let!(:existing_token) { creator.call(client, scopes, expires_in: 1000) }

    before do
      allow(Doorkeeper.configuration).to receive(:revoke_previous_client_credentials_token?).and_return(true)
    end

    it "revokes the existing token" do
      creator.call(client, scopes, expires_in: 1000)
      expect(existing_token.reload).to be_revoked
    end
  end

  context "when revoke_previous_client_credentials_token is false" do
    let!(:existing_token) { creator.call(client, scopes, expires_in: 1000) }

    before do
      allow(Doorkeeper.configuration).to receive(:revoke_previous_client_credentials_token?).and_return(false)
    end

    it "does not revoke the existing token" do
      creator.call(client, scopes, expires_in: 1000)
      expect(existing_token.reload).not_to be_revoked
    end
  end

  context "when stateless_jwt_tokens is enabled" do
    before do
      stub_const(
        "StatelessCreatorSpecGenerator",
        Class.new do
          def self.generate(options)
            "stateless-jwt-#{options[:application].uid}-#{options[:created_at].to_i}"
          end
        end,
      )

      config_is_set(:stateless_jwt_tokens, true)
      config_is_set(:access_token_generator, "StatelessCreatorSpecGenerator")
      config_is_set(:jwt_token_decoder, ->(_raw) { {} })
    end

    it "builds a StatelessToken without persisting a row" do
      result = nil

      expect { result = creator.call(client, scopes, expires_in: 1000) }
        .not_to(change { Doorkeeper::AccessToken.count })

      expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
      expect(result.plaintext_token).to start_with("stateless-jwt-#{client.uid}-")
      expect(result.application).to eq(client)
      expect(result.scopes_string).to eq("public")
      expect(result.resource_owner_id).to be_nil
      expect(result.expires_in).to eq(1000)
    end

    # The Issuer passes `expires_in: nil` when custom_access_token_expires_in
    # returns Float::INFINITY; create_for records that as a non-expiring row.
    it "keeps a non-expiring token when expires_in is nil" do
      expect(Doorkeeper.config.access_token_expires_in).to be_present

      result = creator.call(client, scopes, expires_in: nil)

      expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
      expect(result.expires_in).to be_nil
      expect(result.expires_at).to be_nil
      expect(result.expires_in_seconds).to be_nil
      expect(result).to be_accessible
    end

    it "forwards custom token attributes to the generator" do
      allow(Doorkeeper.config).to receive(:custom_access_token_attributes).and_return([:tenant_name])

      expect(StatelessCreatorSpecGenerator).to receive(:generate)
        .with(hash_including(tenant_name: "Me"))
        .and_call_original

      result = creator.call(client, scopes, tenant_name: "Me")

      expect(result.custom_attributes).to eq("tenant_name" => "Me")
    end

    # ClientCredentialsRequest#custom_token_attributes_with_data supplies
    # symbol keys whatever the configured attribute names are.
    it "forwards custom token attributes configured by string names to the generator" do
      allow(Doorkeeper.config).to receive(:custom_access_token_attributes).and_return(["tenant_name"])

      expect(StatelessCreatorSpecGenerator).to receive(:generate)
        .with(hash_including("tenant_name" => "Me"))
        .and_call_original

      result = creator.call(client, scopes, tenant_name: "Me")

      expect(result.custom_attributes).to eq("tenant_name" => "Me")
    end

    it "resolves the application from an authenticated client wrapper" do
      result = creator.call(Doorkeeper::OAuth::Client.new(client), scopes)

      expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
      expect(result.application).to eq(client)
    end

    context "when reuse_access_token is true" do
      before do
        allow(Doorkeeper.config).to receive(:reuse_access_token).and_return(true)
      end

      it "does not look for a reusable token" do
        expect(Doorkeeper::AccessToken).not_to receive(:matching_token_for)

        expect(creator.call(client, scopes)).to be_a(Doorkeeper::OAuth::StatelessToken)
      end
    end

    context "when the access token model does not implement build_stateless_token" do
      before do
        stub_const("LegacyAccessToken", Class.new)
        allow(Doorkeeper.config).to receive(:access_token_model).and_return(LegacyAccessToken)
      end

      it "raises StatelessTokensUnsupported instead of NoMethodError" do
        expect { creator.call(client, scopes) }
          .to raise_error(Doorkeeper::Errors::StatelessTokensUnsupported, /LegacyAccessToken/)
      end

      context "when revoke_previous_client_credentials_token is true" do
        before do
          allow(Doorkeeper.config).to receive(:revoke_previous_client_credentials_token?).and_return(true)
        end

        # The revocation lookup calls extract_custom_attributes and
        # matching_token_for, which the model does not define either; the
        # capability check has to come first.
        it "raises StatelessTokensUnsupported before the revocation lookup" do
          expect { creator.call(client, scopes) }
            .to raise_error(Doorkeeper::Errors::StatelessTokensUnsupported, /LegacyAccessToken/)
        end
      end
    end

    context "when revoke_previous_client_credentials_token is true" do
      let!(:persisted_token) do
        FactoryBot.create(:access_token, application: client, resource_owner_id: nil, scopes: "public")
      end

      before do
        allow(Doorkeeper.config).to receive(:revoke_previous_client_credentials_token?).and_return(true)
      end

      it "revokes a token persisted before the option was enabled" do
        result = creator.call(client, scopes)

        expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
        expect(persisted_token.reload).to be_revoked
      end
    end
  end
end

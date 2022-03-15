# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientCredentials::Issuer do
  subject(:issuer) { described_class.new(server, validator) }

  let(:creator) { double :access_token_creator }
  let(:server) do
    double(
      :server,
      access_token_expires_in: 100,
    )
  end
  let(:validator) { double :validator, valid?: true, resource_indicators: [] }

  before do
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(false)
  end

  describe "#create" do
    let(:client) { double :client, id: "some-id" }
    let(:scopes) { "some scope" }

    it "creates and sets the token" do
      expect(creator).to receive(:call).and_return("token")
      issuer.create client, scopes, creator

      expect(issuer.token).to eq("token")
    end

    it "creates with correct token parameters" do
      expect(creator).to receive(:call).with(
        client,
        scopes,
        resource_indicators: [],
        expires_in: 100,
        use_refresh_token: false,
      )

      issuer.create client, scopes, creator
    end

    it "has error set to :server_error if creator fails" do
      expect(creator).to receive(:call).and_return(false)
      issuer.create client, scopes, creator

      expect(issuer.error).to eq(:server_error)
    end

    context "when validator fails" do
      before do
        allow(validator).to receive(:valid?).and_return(false)
        allow(validator).to receive(:error).and_return(:validation_error)
      end

      it "has error set from validator" do
        expect(creator).not_to receive(:create)
        issuer.create client, scopes, creator
        expect(issuer.error).to eq(:validation_error)
      end

      it "returns false" do
        expect(issuer.create(client, scopes, creator)).to be_falsey
      end
    end

    context "with custom expiration" do
      let(:custom_ttl_grant) { 1234 }
      let(:custom_ttl_scope) { 1235 }
      let(:custom_scope) { "special" }
      let(:server) do
        double(
          :server,
          custom_access_token_expires_in: lambda { |context|
            # scopes is normally an object but is a string in this test
            if context.scopes == custom_scope
              custom_ttl_scope
            elsif context.grant_type == Doorkeeper::OAuth::CLIENT_CREDENTIALS
              custom_ttl_grant
            end
          },
        )
      end

      before do
        allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
      end

      it "respects grant based rules" do
        expect(creator).to receive(:call).with(
          client,
          scopes,
          resource_indicators: [],
          expires_in: custom_ttl_grant,
          use_refresh_token: false,
        )
        issuer.create client, scopes, creator
      end

      it "respects scope based rules" do
        expect(creator).to receive(:call).with(
          client,
          custom_scope,
          resource_indicators: [],
          expires_in: custom_ttl_scope,
          use_refresh_token: false,
        )
        issuer.create client, custom_scope, creator
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientCredentials::Validator do
  subject(:validator) { described_class.new(server, request) }

  let(:server)      { double :server, scopes: nil }
  let(:application) { double scopes: nil, confidential?: true }
  let(:client)      { double application: application }
  let(:request)     { double :request, client: client, scopes: nil }

  it "is valid with valid request" do
    expect(validator).to be_valid
  end

  it "is invalid when client is not present" do
    allow(request).to receive(:client).and_return(nil)
    expect(validator).not_to be_valid
  end

  # RFC 6749 Section 4.4: "The client credentials grant type MUST only be used
  # by confidential clients."
  context "when the client is public" do
    before do
      allow(application).to receive(:confidential?).and_return(false)
    end

    it "is invalid" do
      expect(validator).not_to be_valid
      expect(validator.error).to eq(Doorkeeper::Errors::UnauthorizedClient)
    end

    it "is valid with allow_client_credentials_grant_for_public_clients" do
      config_is_set(:allow_client_credentials_grant_for_public_clients, true)

      expect(validator).to be_valid
    end
  end

  context "when a grant flow check is configured" do
    let(:callback) { double("callback") }

    before do
      allow(Doorkeeper.config).to receive(:option_defined?).with(:allow_grant_flow_for_client).and_return(true)
      allow(Doorkeeper.config).to receive(:allow_grant_flow_for_client).and_return(callback)
    end

    context "when the callback rejects the grant flow" do
      let(:callback_response) { false }

      it "is invalid" do
        expect(callback).to receive(:call).twice.with(
          Doorkeeper::OAuth::CLIENT_CREDENTIALS,
          application,
        ).and_return(callback_response)

        expect(validator).not_to be_valid
      end
    end

    context "when the callback allows the grant flow" do
      let(:callback_response) { true }

      it "is invalid" do
        expect(callback).to receive(:call).twice.with(
          Doorkeeper::OAuth::CLIENT_CREDENTIALS,
          application,
        ).and_return(callback_response)

        expect(validator).to be_valid
      end
    end
  end

  context "with scopes" do
    it "is invalid when scopes are not included in the server" do
      server_scopes = Doorkeeper::OAuth::Scopes.from_string "email"
      allow(server).to receive(:scopes).and_return(server_scopes)
      allow(request).to receive_messages(grant_type: Doorkeeper::OAuth::CLIENT_CREDENTIALS, scopes: Doorkeeper::OAuth::Scopes.from_string("invalid"))
      expect(validator).not_to be_valid
    end

    context "with application scopes" do
      it "is valid when scopes are included in the application" do
        application_scopes = Doorkeeper::OAuth::Scopes.from_string "app"
        server_scopes = Doorkeeper::OAuth::Scopes.from_string "email app"
        allow(application).to receive(:scopes).and_return(application_scopes)
        allow(server).to receive(:scopes).and_return(server_scopes)
        allow(request).to receive_messages(grant_type: Doorkeeper::OAuth::CLIENT_CREDENTIALS, scopes: application_scopes)
        expect(validator).to be_valid
      end

      it "is invalid when scopes are not included in the application" do
        application_scopes = Doorkeeper::OAuth::Scopes.from_string "app"
        server_scopes = Doorkeeper::OAuth::Scopes.from_string "email app"
        allow(application).to receive(:scopes).and_return(application_scopes)
        allow(server).to receive(:scopes).and_return(server_scopes)
        allow(request).to receive_messages(grant_type: Doorkeeper::OAuth::CLIENT_CREDENTIALS, scopes: Doorkeeper::OAuth::Scopes.from_string("email"))
        expect(validator).not_to be_valid
      end
    end
  end
end

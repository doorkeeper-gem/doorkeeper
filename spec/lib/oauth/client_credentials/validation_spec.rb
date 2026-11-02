# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientCredentials::Validator do
  subject(:validator) { described_class.new(server, request) }

  let(:server)      { double :server, scopes: nil }
  let(:application) { double scopes: nil }
  let(:client)      { double application: application }
  let(:request)     { double :request, client: client, scopes: nil }

  it "is valid with valid request" do
    expect(validator).to be_valid
  end

  it "is invalid when client is not present" do
    allow(request).to receive(:client).and_return(nil)
    expect(validator).not_to be_valid
  end

  # `#validate` stops at the first failing check, so once the client is
  # missing the later checks are never reached through `#valid?`. They still
  # have to cope with a missing client on their own.
  context "when the later checks run without a client" do
    before do
      allow(request).to receive(:client).and_return(nil)
    end

    it "skips the grant flow check instead of asking about a missing application" do
      expect(Doorkeeper.config).not_to receive(:allow_grant_flow_for_client?)

      expect(validator.send(:validate_client_supports_grant_flow)).to be_nil
    end

    it "accepts an empty scope request" do
      expect(validator.send(:validate_scopes)).to be(true)
    end

    it "checks the requested scopes against the server scopes alone" do
      server_scopes = Doorkeeper::OAuth::Scopes.from_string("email")
      allow(server).to receive(:scopes).and_return(server_scopes)
      allow(request).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("email"))

      expect(validator.send(:validate_scopes)).to be(true)

      allow(request).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("profile"))

      expect(validator.send(:validate_scopes)).to be(false)
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

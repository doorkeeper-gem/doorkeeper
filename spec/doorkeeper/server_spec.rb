# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Server do
  subject do
    described_class.new(context)
  end

  let(:fake_class) { double :fake_class }
  let(:context) { double :context }

  describe ".authorization_request" do
    it "raises error when strategy does not match phase" do
      expect do
        subject.token_request(:code)
      end.to raise_error(Doorkeeper::Errors::InvalidTokenStrategy)
    end

    context "when only Authorization Code strategy is enabled" do
      before do
        allow(Doorkeeper.configuration)
          .to receive(:grant_flows)
          .and_return(["authorization_code"])
      end

      it "raises error when using the disabled Client Credentials strategy" do
        expect do
          subject.token_request(:client_credentials)
        end.to raise_error(Doorkeeper::Errors::InvalidTokenStrategy)
      end
    end

    it "builds the request with selected strategy" do
      stub_const "Doorkeeper::Request::Code", fake_class
      expect(fake_class).to receive(:new).with(subject)
      subject.authorization_request :code
    end

    it "builds the request with composite strategy name" do
      allow(Doorkeeper.configuration)
        .to receive(:authorization_response_types)
        .and_return(["id_token token"])

      stub_const "Doorkeeper::Request::IdTokenToken", fake_class
      expect(fake_class).to receive(:new).with(subject)
      subject.authorization_request "id_token token"
    end
  end
end

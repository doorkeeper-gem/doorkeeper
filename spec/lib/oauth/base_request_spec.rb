# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::OAuth::BaseRequest do
  let(:access_token) do
    double :access_token,
           plaintext_token: "some-token",
           expires_in: "3600",
           expires_in_seconds: "300",
           scopes_string: "two scopes",
           plaintext_refresh_token: "some-refresh-token",
           token_type: "bearer",
           created_at: 0
  end

  let(:client) { double :client, id: "1" }

  let(:scopes_array) { %w[public write] }

  let(:server) do
    double :server,
           access_token_expires_in: 100,
           custom_access_token_expires_in: ->(_context) { nil },
           refresh_token_enabled?: false
  end

  before do
    allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)
  end

  subject do
    described_class.new
  end

  describe "#authorize" do
    before do
      allow(subject).to receive(:access_token).and_return(access_token)
    end

    it "validates itself" do
      expect(subject).to receive(:validate).once
      subject.authorize
    end

    context "valid" do
      before do
        allow(subject).to receive(:valid?).and_return(true)
      end

      it "calls callback methods" do
        expect(subject).to receive(:before_successful_response).once
        expect(subject).to receive(:after_successful_response).once
        subject.authorize
      end

      it "returns a TokenResponse object" do
        result = subject.authorize

        expect(result).to be_an_instance_of(Doorkeeper::OAuth::TokenResponse)
        expect(result.body).to eq(
          Doorkeeper::OAuth::TokenResponse.new(access_token).body,
        )
      end
    end

    context "invalid" do
      context "with error other than invalid_request" do
        before do
          allow(subject).to receive(:valid?).and_return(false)
          allow(subject).to receive(:error).and_return(:server_error)
          allow(subject).to receive(:state).and_return("hello")
        end

        it "returns an ErrorResponse object" do
          result = subject.authorize

          expect(result).to be_an_instance_of(Doorkeeper::OAuth::ErrorResponse)

          expect(result.body).to eq(
            error: :server_error,
            error_description: translated_error_message(:server_error),
            state: "hello",
          )
        end
      end

      context "with invalid_request error" do
        before do
          allow(subject).to receive(:valid?).and_return(false)
          allow(subject).to receive(:error).and_return(:invalid_request)
          allow(subject).to receive(:state).and_return("hello")
        end

        it "returns an InvalidRequestResponse object" do
          result = subject.authorize

          expect(result).to be_an_instance_of(Doorkeeper::OAuth::InvalidRequestResponse)

          expect(result.body).to eq(
            error: :invalid_request,
            error_description: translated_invalid_request_error_message(:unknown, :unknown),
            state: "hello",
          )
        end
      end
    end
  end

  describe "#default_scopes" do
    it "delegates to the server" do
      expect(subject).to receive(:server).and_return(server).once
      expect(server).to receive(:default_scopes).once

      subject.default_scopes
    end
  end

  describe "#find_or_create_access_token" do
    let(:resource_owner) { FactoryBot.build_stubbed(:resource_owner) }

    it "returns an instance of AccessToken" do
      result = subject.find_or_create_access_token(
        client,
        resource_owner,
        "public",
        server,
      )

      expect(result).to be_an_instance_of(Doorkeeper::AccessToken)
    end

    it "respects custom_access_token_expires_in" do
      server = double(
        :server,
        access_token_expires_in: 100,
        custom_access_token_expires_in: ->(context) { context.scopes == "public" ? 500 : nil },
        refresh_token_enabled?: false,
      )

      allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)

      result = subject.find_or_create_access_token(
        client,
        resource_owner,
        "public",
        server,
      )
      expect(result.expires_in).to eql(500)
    end

    it "respects use_refresh_token with a block" do
      server = double(
        :server,
        access_token_expires_in: 100,
        custom_access_token_expires_in: ->(_context) { nil },
        refresh_token_enabled?: lambda { |context|
          context.scopes == "public"
        },
      )

      allow(server).to receive(:option_defined?).with(:custom_access_token_expires_in).and_return(true)

      result = subject.find_or_create_access_token(
        client,
        resource_owner,
        "public",
        server,
      )
      expect(result.refresh_token).to_not be_nil

      result = subject.find_or_create_access_token(
        client,
        resource_owner,
        "private",
        server,
      )
      expect(result.refresh_token).to be_nil
    end
  end

  describe "#scopes" do
    context "@original_scopes is present" do
      before do
        subject.instance_variable_set(:@original_scopes, "public write")
      end

      it "returns array of @original_scopes" do
        result = subject.scopes

        expect(result).to eq(scopes_array)
      end
    end

    context "@original_scopes is not present" do
      before do
        subject.instance_variable_set(:@original_scopes, "")
      end

      it "calls #default_scopes" do
        allow(subject).to receive(:server).and_return(server).once
        allow(server).to receive(:default_scopes).and_return(scopes_array).once

        result = subject.scopes

        expect(result).to eq(scopes_array)
      end
    end
  end
end

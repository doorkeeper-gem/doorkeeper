# frozen_string_literal: true

require "spec_helper"
require "grape"
require "rack/test"
require "doorkeeper/grape/helpers"

# Test Grape API application
module GrapeApp
  class API < Grape::API
    version "v1", using: :path
    format :json
    prefix :api

    helpers Doorkeeper::Grape::Helpers

    resource :protected do
      before do
        doorkeeper_authorize!
      end

      desc "Protected resource, requires token."

      get :status do
        { token: doorkeeper_token.token }
      end
    end

    resource :protected_with_endpoint_scopes do
      before do
        doorkeeper_authorize!
      end

      desc "Protected resource, requires token with scopes (defined in endpoint)."

      get :status, scopes: [:admin] do
        { response: "OK" }
      end
    end

    resource :protected_with_helper_scopes do
      before do
        doorkeeper_authorize! :admin
      end

      desc "Protected resource, requires token with scopes (defined in helper)."

      get :status do
        { response: "OK" }
      end
    end

    resource :protected_with_endpoint_dpop_required do
      before do
        doorkeeper_authorize!
      end

      desc "Protected resource, requires DPoP token (defined in endpoint)."

      get :status, dpop: :required do
        { response: "OK" }
      end
    end

    resource :protected_with_helper_dpop_required do
      before do
        doorkeeper_authorize! dpop: :required
      end

      desc "Protected resource, requires DPoP token (defined in helper)."

      get :status do
        { response: "OK" }
      end
    end

    resource :public do
      desc "Public resource, no token required."

      get :status do
        { response: "OK" }
      end
    end
  end
end

RSpec.describe "Grape integration" do
  include Rack::Test::Methods

  def app
    GrapeApp::API
  end

  def json_body
    JSON.parse(last_response.body)
  end

  let(:client) { FactoryBot.create(:application) }
  let(:resource) { FactoryBot.create(:doorkeeper_testing_user, name: "Joe", password: "sekret") }
  let(:access_token) { client_is_authorized(client, resource) }

  context "with valid Access Token" do
    it "successfully requests protected resource" do
      get "api/v1/protected/status.json?access_token=#{access_token.token}"

      expect(last_response).to be_successful

      expect(json_body["token"]).to eq(access_token.token)
    end

    it "successfully requests protected resource with token that has required scopes (Grape endpoint)" do
      access_token = client_is_authorized(client, resource, scopes: "admin")

      get "api/v1/protected_with_endpoint_scopes/status.json?access_token=#{access_token.token}"

      expect(last_response).to be_successful
      expect(json_body).to have_key("response")
    end

    it "successfully requests protected resource with token that has required scopes (Doorkeeper helper)" do
      access_token = client_is_authorized(client, resource, scopes: "admin")

      get "api/v1/protected_with_helper_scopes/status.json?access_token=#{access_token.token}"

      expect(last_response).to be_successful
      expect(json_body).to have_key("response")
    end

    it "successfully requests public resource" do
      get "api/v1/public/status.json"

      expect(last_response).to be_successful
      expect(json_body).to have_key("response")
    end

    it "fails request for protected resource that requires dpop (Grape endpoint)" do
      get "api/v1/protected_with_endpoint_dpop_required/status.json?access_token=#{access_token.token}"

      expect(last_response).not_to be_successful
      expect(json_body).to have_key("error")
    end

    it "fails request for protected resource that requires dpop (Doorkeeper helper)" do
      get "api/v1/protected_with_helper_dpop_required/status.json?access_token=#{access_token.token}"

      expect(last_response).not_to be_successful
      expect(json_body).to have_key("error")
    end
  end

  context "with dpop Token", token: :dpop do
    def build_dpop_proof(htu:,
                         ath: Base64.urlsafe_encode64(Digest::SHA256.digest(token_string), padding: false),
                         htm: "GET",
                         signing_key: self.signing_key)
      super
    end

    it "successfully requests protected resource" do
      get "api/v1/protected/status.json",
          {},
          "HTTP_AUTHORIZATION" => "DPoP #{token_string}",
          "HTTP_DPOP" => build_dpop_proof(htu: "http://example.org/api/v1/protected/status.json")

      expect(last_response).to be_successful

      expect(json_body["token"]).to eq(token.token)
    end

    it "successfully requests protected resource that requires dpop (Grape endpoint)" do
      get "api/v1/protected_with_endpoint_dpop_required/status.json",
          {},
          "HTTP_AUTHORIZATION" => "DPoP #{token_string}",
          "HTTP_DPOP" => build_dpop_proof(htu: "http://example.org/api/v1/protected_with_endpoint_dpop_required/status.json")

      expect(last_response).to be_successful
    end

    it "successfully requests protected resource that requires dpop (Doorkeeper helper)" do
      get "api/v1/protected_with_helper_dpop_required/status.json",
          {},
          "HTTP_AUTHORIZATION" => "DPoP #{token_string}",
          "HTTP_DPOP" => build_dpop_proof(htu: "http://example.org/api/v1/protected_with_helper_dpop_required/status.json")

      expect(last_response).to be_successful
    end
  end

  context "with invalid Access Token" do
    it "fails without access token" do
      get "api/v1/protected/status.json"

      expect(last_response).not_to be_successful
      expect(json_body).to have_key("error")
    end

    it "fails for access token without scopes" do
      get "api/v1/protected_with_endpoint_scopes/status.json?access_token=#{access_token.token}"

      expect(last_response).not_to be_successful
      expect(json_body).to have_key("error")
    end

    it "fails for access token with invalid scopes" do
      access_token = client_is_authorized(client, resource, scopes: "read write")

      get "api/v1/protected_with_endpoint_scopes/status.json?access_token=#{access_token.token}"

      expect(last_response).not_to be_successful
      expect(json_body).to have_key("error")
    end
  end
end

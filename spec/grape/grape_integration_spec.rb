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

      # Reachable with a form-encoded body, so a request can present a token
      # through RFC 6750 §2.2 and §2.3 at the same time.
      post :status do
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

    # doorkeeper_token is consulted several times while the error response is
    # rendered; a nil outcome must be memoized like a token is, or every
    # consultation runs the whole authentication again.
    it "authenticates only once per request" do
      expect(Doorkeeper::OAuth::Token).to receive(:resolve).once.and_call_original

      get "api/v1/protected/status.json?access_token=unknown-token"

      expect(last_response).not_to be_successful
      expect(json_body).to have_key("error")
    end
  end

  # RFC 6750 §2 forbids transmitting the token by more than one method, and
  # §3.1 answers it with invalid_request (400), not invalid_token (401).
  context "with tokens transmitted by more than one method" do
    it "refuses the request with invalid_request when two methods present different tokens" do
      get "api/v1/protected/status.json?access_token=another-token",
          {},
          { "HTTP_AUTHORIZATION" => "Bearer #{access_token.token}" }

      expect(last_response.status).to eq(400)
      expect(last_response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    # §2 forbids using more than one method, not presenting two different
    # tokens, so repeating one token across two methods is refused as well.
    it "refuses the same token repeated across methods" do
      get "api/v1/protected/status.json?access_token=#{access_token.token}",
          {},
          { "HTTP_AUTHORIZATION" => "Bearer #{access_token.token}" }

      expect(last_response.status).to eq(400)
      expect(last_response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    # The form-encoded body (§2.2) and the URI query (§2.3) are two methods,
    # but Rack merges them into one parameter hash — letting the body win,
    # the opposite of ActionDispatch — so the query token would otherwise be
    # discarded without a word.
    it "refuses different tokens presented in the body and in the query" do
      post "api/v1/protected/status.json?access_token=another-token",
           { access_token: access_token.token }

      expect(last_response.status).to eq(400)
      expect(last_response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    it "refuses the same token repeated in the body and in the query" do
      post "api/v1/protected/status.json?access_token=#{access_token.token}",
           { access_token: access_token.token }

      expect(last_response.status).to eq(400)
      expect(last_response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    # Grape parses a JSON body itself and merges the result into Rack's form
    # hash, so the body/query check sees it the same way it sees a
    # form-encoded body — and the same way ActionDispatch exposes a parsed
    # JSON body through +POST+.
    it "refuses a token presented in a JSON body and in the query" do
      post "api/v1/protected/status.json?access_token=#{access_token.token}",
           { access_token: access_token.token }.to_json,
           { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(400)
      expect(last_response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    it "refuses a token presented in a JSON body and in the Authorization header" do
      post "api/v1/protected/status.json",
           { access_token: access_token.token }.to_json,
           { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token.token}" }

      expect(last_response.status).to eq(400)
      expect(last_response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    it "accepts a token presented only in a JSON body" do
      post "api/v1/protected/status.json",
           { access_token: access_token.token }.to_json,
           { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(201)
      expect(json_body["token"]).to eq(access_token.token)
    end
  end
end

# frozen_string_literal: true

# End-to-end coverage for the custom grant flow registry [#1418] with a
# URN-shaped grant type, mirroring the README "Custom Grant Flows" example.

require "spec_helper"

module SamlBearerExample
  Assertion = Struct.new(:name_id)

  class TokenRequest < Doorkeeper::OAuth::BaseRequest
    validate :client, error: Doorkeeper::Errors::InvalidClient
    validate :client_supports_grant_flow, error: Doorkeeper::Errors::UnauthorizedClient
    validate :assertion, error: Doorkeeper::Errors::InvalidGrant
    validate :scopes, error: Doorkeeper::Errors::InvalidScope

    attr_reader :client, :parameters, :access_token

    def initialize(server, client, parameters = {})
      @server          = server
      @client          = client
      @parameters      = parameters
      @original_scopes = parameters[:scope]
      @grant_type      = "urn:ietf:params:oauth:grant-type:saml2-bearer"
    end

    private

    def before_successful_response
      find_or_create_access_token(client, resource_owner, scopes, {}, server)
      super
    end

    def assertion
      @assertion ||= decode_and_verify_saml(parameters[:assertion])
    end

    # Stands in for real SAML verification (ruby-saml etc.)
    def decode_and_verify_saml(raw)
      Assertion.new("Joe") if raw == "valid-saml-assertion"
    end

    def resource_owner
      @resource_owner ||= User.find_by(name: assertion.name_id)
    end

    def validate_client
      client.present?
    end

    def validate_client_supports_grant_flow
      Doorkeeper.config.allow_grant_flow_for_client?(grant_type, client&.application)
    end

    def validate_assertion
      assertion.present? && resource_owner.present?
    end

    def validate_scopes
      return true if scopes.blank?

      Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
        scope_str: scopes.to_s,
        server_scopes: server.scopes,
        app_scopes: client&.scopes,
        grant_type: grant_type,
      )
    end
  end

  class Strategy < Doorkeeper::Request::Strategy
    delegate :client, :parameters, to: :server

    def request
      @request ||= TokenRequest.new(Doorkeeper.config, client, parameters)
    end
  end
end

RSpec.describe "Custom SAML bearer grant flow (README example)" do
  let(:client) { FactoryBot.create :application }
  let!(:user) { FactoryBot.create :resource_owner, name: "Joe" }

  before do
    Doorkeeper::GrantFlow.register(
      :saml2_bearer,
      grant_type_matches: "urn:ietf:params:oauth:grant-type:saml2-bearer",
      grant_type_strategy: SamlBearerExample::Strategy,
    )

    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      grant_flows %w[authorization_code saml2_bearer]
    end
  end

  after do
    Doorkeeper::GrantFlow.flows.delete(:saml2_bearer)
  end

  def authorization(username, password)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials username, password
    { "HTTP_AUTHORIZATION" => credentials }
  end

  it "issues a token for a valid assertion" do
    headers = authorization client.uid, client.secret
    params = {
      grant_type: "urn:ietf:params:oauth:grant-type:saml2-bearer",
      assertion: "valid-saml-assertion",
    }

    post token_endpoint_url, params: params, headers: headers

    expect(response.status).to eq(200)
    token = Doorkeeper::AccessToken.first
    expect(token.resource_owner_id).to eq(user.id)
    expect(json_response).to include("access_token" => token.token)
  end

  it "rejects an unverifiable assertion with invalid_grant" do
    headers = authorization client.uid, client.secret
    params = {
      grant_type: "urn:ietf:params:oauth:grant-type:saml2-bearer",
      assertion: "garbage",
    }

    post token_endpoint_url, params: params, headers: headers

    expect(response.status).to eq(400)
    expect(json_response).to include("error" => "invalid_grant")
  end

  it "rejects clients barred from the flow with unauthorized_client" do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      grant_flows %w[authorization_code saml2_bearer]
      allow_grant_flow_for_client do |grant_flow, _application|
        grant_flow != "urn:ietf:params:oauth:grant-type:saml2-bearer"
      end
    end

    headers = authorization client.uid, client.secret
    params = {
      grant_type: "urn:ietf:params:oauth:grant-type:saml2-bearer",
      assertion: "valid-saml-assertion",
    }

    post token_endpoint_url, params: params, headers: headers

    expect(response.status).to eq(400)
    expect(json_response).to include("error" => "unauthorized_client")
  end

  it "still rejects unregistered grant types" do
    headers = authorization client.uid, client.secret
    params = { grant_type: "urn:example:unknown" }

    post token_endpoint_url, params: params, headers: headers

    expect(response.status).to eq(400)
    expect(json_response).to include("error" => "unsupported_grant_type")
  end
end

# frozen_string_literal: true

require "spec_helper"

# A resource_indicator_validator configured without the migration that adds the
# `resource` column to the access token table: every grant that would have to
# record an audience raises MissingResourceColumn, which the token endpoint
# turns into a server_error rather than leaking the operator
# message to the client. The client_credentials grant is covered alongside its
# own flow in spec/requests/flows/client_credentials_spec.rb.
RSpec.describe "Resource Indicators (RFC 8707) when the resource column is missing" do
  let(:resource_uri) { "https://api.example.com/" }

  before do
    default_scopes_exist :default
    config_is_set(:resource_indicator_validator, ->(_indicators, _client) { true })
    client_exists
    create_resource_owner

    allow(Doorkeeper.config.access_token_model).to receive(:resource_indicators_supported?).and_return(false)
  end

  shared_examples "a server_error at the token endpoint" do
    it "returns server_error without issuing a token" do
      expect { post token_endpoint_url, params: params }
        .not_to(change { Doorkeeper::AccessToken.count })

      expect(response.status).to eq(400)
      expect(json_response["error"]).to eq("server_error")
      expect(json_response["error_description"]).to eq(translated_error_message(:server_error))
      expect(json_response["error_description"]).not_to include("resource_indicator_validator")
    end
  end

  context "when exchanging an authorization code whose grant stored a resource" do
    let(:params) { token_endpoint_params(code: @authorization.token, client: @client) }

    before do
      authorization_code_exists(
        application: @client,
        resource_owner_id: @resource_owner.id,
        resource_owner_type: @resource_owner.class.name,
        resource: resource_uri,
      )
    end

    it_behaves_like "a server_error at the token endpoint"
  end

  context "when the password grant asks for a resource" do
    let(:params) do
      password_token_endpoint_params(client: @client, resource_owner: @resource_owner).merge(resource: resource_uri)
    end

    before do
      config_is_set(:grant_flows, ["password"])
      config_is_set(:resource_owner_from_credentials) { User.authenticate! params[:username], params[:password] }
    end

    it_behaves_like "a server_error at the token endpoint"
  end

  context "when refreshing a token and asking for a resource" do
    let(:params) do
      refresh_token_endpoint_params(client: @client, refresh_token: @access_token.refresh_token).merge(resource: resource_uri)
    end

    before do
      config_is_set(:refresh_token_enabled, true)
      access_token_exists(
        application: @client,
        resource_owner_id: @resource_owner.id,
        resource_owner_type: @resource_owner.class.name,
        use_refresh_token: true,
        resource: resource_uri,
      )
    end

    it_behaves_like "a server_error at the token endpoint"
  end
end

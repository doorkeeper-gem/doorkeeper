# frozen_string_literal: true

require "spec_helper"

describe "Client Credentials Request" do
  let(:client) { FactoryBot.create :application }

  context "a valid request" do
    it "authorizes the client and returns the token response" do
      headers = authorization client.uid, client.secret
      params  = { grant_type: "client_credentials" }

      post "/oauth/token", params: params, headers: headers

      should_have_json "access_token", Doorkeeper::AccessToken.first.token
      should_have_json_within "expires_in", Doorkeeper.configuration.access_token_expires_in, 1
      should_not_have_json "scope"
      should_not_have_json "refresh_token"

      should_not_have_json "error"
      should_not_have_json "error_description"
    end

    context "with scopes" do
      before do
        optional_scopes_exist :write
        default_scopes_exist :public
      end

      it "adds the scope to the token an returns in the response" do
        headers = authorization client.uid, client.secret
        params  = { grant_type: "client_credentials", scope: "write" }

        post "/oauth/token", params: params, headers: headers

        should_have_json "access_token", Doorkeeper::AccessToken.first.token
        should_have_json "scope", "write"
      end

      context "that are default" do
        it "adds the scope to the token an returns in the response" do
          headers = authorization client.uid, client.secret
          params  = { grant_type: "client_credentials", scope: "public" }

          post "/oauth/token", params: params, headers: headers

          should_have_json "access_token", Doorkeeper::AccessToken.first.token
          should_have_json "scope", "public"
        end
      end

      context "that are invalid" do
        it "does not authorize the client and returns the error" do
          headers = authorization client.uid, client.secret
          params  = { grant_type: "client_credentials", scope: "random" }

          post "/oauth/token", params: params, headers: headers

          should_have_json "error", "invalid_scope"
          should_have_json "error_description", translated_error_message(:invalid_scope)
          should_not_have_json "access_token"

          expect(response.status).to eq(400)
        end
      end
    end

    context "with a token_creation_wrapper" do
      it "wraps token creation" do
        # Creating the wrapper here so we have access to wrapper_count
        wrapper_count = 0
        wrapper = ->(&block) do
          wrapper_count += 1
          block.call(repeat_find: false)
        end
        config_is_set(:token_creation_wrapper, wrapper)

        headers = authorization client.uid, client.secret
        params  = { grant_type: "client_credentials" }

        post "/oauth/token", params: params, headers: headers

        should_have_json "access_token", Doorkeeper::AccessToken.first.token
        should_have_json_within "expires_in", Doorkeeper.configuration.access_token_expires_in, 1
        expect(wrapper_count).to eq 1

        headers = authorization client.uid, client.secret
        params  = { grant_type: "client_credentials" }

        post "/oauth/token", params: params, headers: headers

        should_have_json "access_token", Doorkeeper::AccessToken.last.token
        should_have_json_within "expires_in", Doorkeeper.configuration.access_token_expires_in, 1
        expect(wrapper_count).to eq 2
      end
    end
  end

  context "when configured to check application supported grant flow" do
    before do
      Doorkeeper.configuration.instance_variable_set(
        :@allow_grant_flow_for_client,
        ->(_grant_flow, client) { client.name == "admin" },
      )
    end

    scenario "forbids the request when doesn't satisfy condition" do
      client.update(name: "sample app")

      headers = authorization client.uid, client.secret
      params  = { grant_type: "client_credentials" }

      post "/oauth/token", params: params, headers: headers

      should_have_json "error", "unauthorized_client"
      should_have_json "error_description", translated_error_message(:unauthorized_client)
    end

    scenario "allows the request when satisfies condition" do
      client.update(name: "admin")

      headers = authorization client.uid, client.secret
      params  = { grant_type: "client_credentials" }

      post "/oauth/token", params: params, headers: headers

      should_have_json "access_token", Doorkeeper::AccessToken.first.token
      should_have_json_within "expires_in", Doorkeeper.configuration.access_token_expires_in, 1
      should_not_have_json "scope"
      should_not_have_json "refresh_token"

      should_not_have_json "error"
      should_not_have_json "error_description"
    end
  end

  context "when application scopes contain some of the default scopes and no scope is passed" do
    before do
      client.update(scopes: "read write public")
    end

    it "issues new token with one default scope that are present in application scopes" do
      default_scopes_exist :public

      headers = authorization client.uid, client.secret
      params  = { grant_type: "client_credentials" }

      expect do
        post "/oauth/token", params: params, headers: headers
      end.to change { Doorkeeper::AccessToken.count }.by(1)

      token = Doorkeeper::AccessToken.first

      expect(token.application_id).to eq client.id
      should_have_json "access_token", token.token
      should_have_json "scope", "public"
    end

    it "issues new token with multiple default scopes that are present in application scopes" do
      default_scopes_exist :public, :read, :update

      headers = authorization client.uid, client.secret
      params  = { grant_type: "client_credentials" }

      expect do
        post "/oauth/token", params: params, headers: headers
      end.to change { Doorkeeper::AccessToken.count }.by(1)

      token = Doorkeeper::AccessToken.first

      expect(token.application_id).to eq client.id
      should_have_json "access_token", token.token
      should_have_json "scope", "public read"
    end
  end

  context "an invalid request" do
    it "does not authorize the client and returns the error" do
      headers = {}
      params  = { grant_type: "client_credentials" }

      post "/oauth/token", params: params, headers: headers

      should_have_json "error", "invalid_client"
      should_have_json "error_description", translated_error_message(:invalid_client)
      should_not_have_json "access_token"

      expect(response.status).to eq(401)
    end
  end

  context "when revoke_previous_client_credentials_token is true" do
    before do
      allow(Doorkeeper.config).to receive(:reuse_access_token) { false }
      allow(Doorkeeper.config).to receive(:revoke_previous_client_credentials_token) { true }
    end

    it "revokes the previous token" do
      headers = authorization client.uid, client.secret
      params  = { grant_type: "client_credentials" }

      post "/oauth/token", params: params, headers: headers
      should_have_json "access_token", Doorkeeper::AccessToken.first.token

      token = Doorkeeper::AccessToken.first

      post "/oauth/token", params: params, headers: headers
      should_have_json "access_token", Doorkeeper::AccessToken.last.token

      expect(token.reload.revoked?).to be_truthy
      expect(Doorkeeper::AccessToken.last.revoked?).to be_falsey
    end

    context "with a simultaneous request" do
      let!(:access_token) { FactoryBot.create :access_token, resource_owner_id: nil }

      before do
        allow(Doorkeeper.config.access_token_model).to receive(:matching_token_for) { access_token }
        allow(access_token).to receive(:revoked?).and_return(true)
      end

      it "returns an error" do
        headers = authorization client.uid, client.secret
        params  = { grant_type: "client_credentials" }

        post "/oauth/token", params: params, headers: headers
        should_not_have_json "access_token"
        should_have_json "error", "invalid_token_reuse"
      end
    end
  end

  def authorization(username, password)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials username, password
    { "HTTP_AUTHORIZATION" => credentials }
  end
end

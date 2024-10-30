# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::TokensController, type: :controller do
  render_views

  subject(:json) { JSON.parse(response.body) }

  let(:client) { FactoryBot.create :application }
  let!(:user)  { User.create!(name: "Joe", password: "sekret") }

  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      resource_owner_from_credentials do
        User.first
      end
    end

    allow(Doorkeeper.configuration).to receive(:grant_flows).and_return(["password"])
  end

  describe "POST #create" do
    before do
      post :create, params: {
        client_id: client.uid,
        client_secret: client.secret,
        grant_type: "password",
      }
    end

    it "responds after authorization" do
      expect(response).to be_successful
    end

    it "includes access token in response" do
      expect(json["access_token"]).to eq(Doorkeeper::AccessToken.first.token)
    end

    it "includes token type in response" do
      expect(json["token_type"]).to eq("Bearer")
    end

    it "includes token expiration in response" do
      expect(json["expires_in"].to_i).to eq(Doorkeeper.configuration.access_token_expires_in)
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe "POST #create with errors" do
    before do
      post :create, params: {
        client_id: client.uid,
        client_secret: "invalid",
        grant_type: "password",
      }
    end

    it "responds after authorization" do
      expect(response).to be_unauthorized
    end

    it "include error in response" do
      expect(json["error"]).to eq("invalid_client")
    end

    it "include error_description in response" do
      expect(json["error_description"]).to be_present
    end

    it "does not include access token in response" do
      expect(json["access_token"]).to be_nil
    end

    it "does not include token type in response" do
      expect(json["token_type"]).to be_nil
    end

    it "does not include token expiration in response" do
      expect(json["expires_in"]).to be_nil
    end

    it "does not issue any access token" do
      expect(Doorkeeper::AccessToken.all).to be_empty
    end
  end

  describe "POST #create with callbacks" do
    after do
      client.update_attribute :redirect_uri, "urn:ietf:wg:oauth:2.0:oob"
    end

    describe "when successful" do
      after do
        post :create, params: {
          client_id: client.uid,
          client_secret: client.secret,
          grant_type: "password",
        }
      end

      it "calls :before_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:before_successful_authorization, :call).with(instance_of(described_class), nil)
      end

      it "calls :after_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:after_successful_authorization, :call)
          .with(instance_of(described_class), instance_of(Doorkeeper::OAuth::Hooks::Context))
      end
    end

    describe "with errors" do
      after do
        post :create, params: {
          client_id: client.uid,
          client_secret: "invalid",
          grant_type: "password",
        }
      end

      it "calls :before_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:before_successful_authorization, :call).with(instance_of(described_class), nil)
      end

      it "does not call :after_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:after_successful_authorization)
      end
    end
  end

  describe "POST #create with custom error" do
    it "returns the error response with a custom message" do
      # I18n looks for `doorkeeper.errors.messages.custom_message` in locale files
      custom_message = "my_message"
      allow(I18n).to receive(:translate)
        .with(
          custom_message,
          hash_including(scope: %i[doorkeeper errors messages]),
        )
        .and_return("Authorization custom message")

      doorkeeper_error = Doorkeeper::Errors::DoorkeeperError.new(custom_message)

      strategy = double(:strategy)
      request = double(token_request: strategy)
      allow(strategy).to receive(:authorize).and_raise(doorkeeper_error)
      allow(controller).to receive(:server).and_return(request)

      post :create

      expected_response_body = {
        "error" => custom_message,
        "error_description" => "Authorization custom message",
      }
      expect(response.status).to eq 400
      expect(response.headers["WWW-Authenticate"]).to match(/Bearer/)
      expect(JSON.parse(response.body)).to eq expected_response_body
    end
  end

  # https://datatracker.ietf.org/doc/html/rfc7009#section-2.2
  describe "POST #revoke" do
    let(:client) { FactoryBot.create(:application) }
    let(:revoked_at) { nil }
    let(:access_token) do
      FactoryBot.create(
        :access_token,
        application: client,
        revoked_at: revoked_at,
        use_refresh_token: true
      )
    end

    context "when associated app is public" do
      let(:client) { FactoryBot.create(:application, confidential: false) }

      it "returns 200" do
        post :revoke, params: { client_id: client.uid, token: access_token.token }

        expect(response.status).to eq 200
      end

      it "does not revoke the access token when token_type_hint == refresh_token" do
        post :revoke, params: {
          client_id: client.uid,
          token: access_token.token,
          token_type_hint: "refresh_token",
        }

        expect(response.status).to eq 200

        expect(access_token.reload).to have_attributes(revoked?: false)
      end

      it "revokes the refresh token when token_type_hint == refresh_token" do
        post :revoke, params: {
          client_id: client.uid,
          token: access_token.refresh_token,
          token_type_hint: "refresh_token",
        }

        expect(response.status).to eq 200

        expect(access_token.reload).to have_attributes(revoked?: true)
      end

      it "revokes the refresh token when token_type_hint not passed" do
        post :revoke, params: {
          client_id: client.uid,
          token: access_token.refresh_token,
        }

        expect(response.status).to eq 200

        expect(access_token.reload).to have_attributes(revoked?: true)
      end

      context "when access_token has already been revoked" do
        let(:revoked_at) { 1.day.ago.floor }

        it "does not update the revoked_at when the access token has already been revoked" do
          post :revoke, params: {
            client_id: client.uid,
            token: access_token.token,
          }

          expect(response.status).to eq 200

          expect(access_token.reload).to have_attributes(revoked_at: revoked_at)
        end

        it "does not update the revoked_at when the refresh token has already been revoked" do
          post :revoke, params: {
            client_id: client.uid,
            token: access_token.refresh_token,
          }

          expect(response.status).to eq 200

          expect(access_token.reload).to have_attributes(revoked_at: revoked_at)
        end
      end

      it "does not revoke when the access token has expired" do
        access_token.update!(created_at: access_token.created_at - access_token.expires_in - 1)

        post :revoke, params: {
          client_id: client.uid,
          token: access_token.token,
        }

        expect(response.status).to eq 200

        expect(access_token.reload).to have_attributes(revoked?: false)
      end

      it "revokes the refresh token after the access token has expired" do
        access_token.update!(created_at: access_token.created_at - access_token.expires_in - 1)

        post :revoke, params: {
          client_id: client.uid,
          token: access_token.refresh_token,
        }

        expect(response.status).to eq 200

        expect(access_token.reload).to have_attributes(revoked?: true)
      end
    end

    context "when associated app is confidential" do
      let(:client) { FactoryBot.create(:application, confidential: true) }
      let(:oauth_client) { Doorkeeper::OAuth::Client.new(client) }
      let(:server) { instance_double(Doorkeeper::Server) }

      before do
        allow(Doorkeeper::Server).to receive(:new).and_return(server)
        allow(server).to receive(:client).and_return(oauth_client)
      end

      it "returns 200" do
        post :revoke, params: { token: access_token.token }

        expect(response.status).to eq 200
      end

      it "revokes the access token" do
        post :revoke, params: { token: access_token.token }

        expect(access_token.reload).to have_attributes(revoked?: true)
      end

      context "when authorization fails" do
        let(:some_other_client) { FactoryBot.create(:application, confidential: true) }
        let(:oauth_client) { Doorkeeper::OAuth::Client.new(some_other_client) }

        it "returns 403" do
          post :revoke, params: { token: access_token.token }

          expect(response.status).to eq 403
        end

        it "does not revoke the access token" do
          post :revoke, params: { token: access_token.token }

          expect(access_token.reload).to have_attributes(revoked?: false)
        end
      end
    end
  end

  describe "POST #introspect" do
    let(:client) { FactoryBot.create(:application) }
    let(:access_token) { FactoryBot.create(:access_token, application: client) }
    let(:token_for_introspection) { FactoryBot.create(:access_token, application: client) }

    context "when authorized using valid Bearer token" do
      it "responds with full token introspection" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to include("active" => true)
        expect(json_response).to include("client_id", "token_type", "exp", "iat")
      end
    end

    context "when authorized using Client Credentials of the client that token is issued to" do
      it "responds with full token introspection" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match(
          "active" => true,
          "client_id" => client.uid,
          "token_type" => "Bearer",
          "scope" => nil,
          "exp" => an_instance_of(Integer),
          "iat" => an_instance_of(Integer),
        )
      end
    end

    context "when token introspection disabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          allow_token_introspection false
        end
      end

      it "responds with invalid_token error for bearer auth" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        response_status_should_be 401

        expect(json_response).not_to include("active")
        expect(json_response).to include("error" => "invalid_token")
      end

      it "responds with access_denied error for basic auth" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        response_status_should_be 200

        expect(json_response).to include("active" => false)
      end
    end

    context "when custom introspection response configured" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          custom_introspection_response do |_token, _context|
            {
              sub: "Z5O3upPC88QrAjx00dis",
              aud: "https://protected.example.net/resource",
            }
          end
        end
      end

      it "responds with full token introspection" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match(
          "active" => true,
          "client_id" => client.uid,
          "token_type" => "Bearer",
          "scope" => nil,
          "exp" => an_instance_of(Integer),
          "iat" => an_instance_of(Integer),
          "aud" => "https://protected.example.net/resource",
          "sub" => "Z5O3upPC88QrAjx00dis",
        )
      end
    end

    context "when access token is public" do
      let(:token_for_introspection) { FactoryBot.create(:access_token, application: nil) }

      it "responds with full token introspection" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match(
          "active" => true,
          "client_id" => nil,
          "token_type" => "Bearer",
          "scope" => nil,
          "exp" => an_instance_of(Integer),
          "iat" => an_instance_of(Integer),
        )
      end
    end

    context "when token was issued to a different client than is making this request" do
      let(:different_client) { FactoryBot.create(:application) }

      it "responds with only active state" do
        request.headers["Authorization"] = basic_auth_header_for_client(different_client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(response).to be_successful

        expect(json_response).to match("active" => false)
      end
    end

    context "when introspection request authorized by a client and allow_token_introspection is true" do
      let(:different_client) { FactoryBot.create(:application) }

      before do
        allow(Doorkeeper.configuration).to receive(:allow_token_introspection).and_return(proc do
          true
        end)
      end

      it "responds with full token introspection" do
        request.headers["Authorization"] = basic_auth_header_for_client(different_client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match(
          "active" => true,
          "client_id" => client.uid,
          "token_type" => "Bearer",
          "scope" => nil,
          "exp" => an_instance_of(Integer),
          "iat" => an_instance_of(Integer),
        )
      end
    end

    context "when allow_token_introspection requires authorized token with special scope" do
      let(:access_token) { FactoryBot.create(:access_token, scopes: "introspection") }

      before do
        allow(Doorkeeper.configuration).to receive(:allow_token_introspection).and_return(proc do |_token, _client, authorized_token|
          authorized_token.scopes.include?("introspection")
        end)
      end

      it "responds with full token introspection if authorized token has introspection scope" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match(
          "active" => true,
          "client_id" => client.uid,
          "token_type" => "Bearer",
          "scope" => nil,
          "exp" => an_instance_of(Integer),
          "iat" => an_instance_of(Integer),
        )
      end

      it "responds with invalid_token error if authorized token doesn't have introspection scope" do
        access_token.update(scopes: "read write")

        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        response_status_should_be 401

        expect(json_response).to match(
          "error" => "invalid_token",
          "error_description" => an_instance_of(String),
          "state" => "unauthorized",
        )
      end
    end

    context "when authorized using invalid Bearer token" do
      let(:access_token) do
        FactoryBot.create(:access_token, application: client, revoked_at: 1.day.ago)
      end

      it "responds with invalid_token error" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: token_for_introspection.token }

        response_status_should_be 401

        expect(json_response).to match(
          "error" => "invalid_token",
          "error_description" => an_instance_of(String),
          "state" => "unauthorized",
        )
      end
    end

    context "when authorized using the Bearer token that need to be introspected" do
      it "responds with invalid token error" do
        request.headers["Authorization"] = "Bearer #{access_token.token}"

        post :introspect, params: { token: access_token.token }

        response_status_should_be 401

        expect(json_response).to match(
          "error" => "invalid_token",
          "error_description" => an_instance_of(String),
          "state" => "unauthorized",
        )
      end
    end

    context "when invalid credentials used to authorize" do
      let(:client) { double(uid: "123123", secret: "666999") }
      let(:access_token) { FactoryBot.create(:access_token) }

      it "responds with invalid_client error" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: access_token.token }

        expect(response).not_to be_successful
        response_status_should_be 401

        expect(json_response).to match(
          "error" => "invalid_client",
          "error_description" => an_instance_of(String),
        )
      end
    end

    context "when wrong token value used" do
      context "when authorized using client credentials" do
        it "responds with only active state" do
          request.headers["Authorization"] = basic_auth_header_for_client(client)

          post :introspect, params: { token: SecureRandom.hex(16) }

          expect(json_response).to match("active" => false)
        end
      end

      context "when authorized using valid Bearer token" do
        it "responds with invalid_token error" do
          request.headers["Authorization"] = "Bearer #{access_token.token}"

          post :introspect, params: { token: SecureRandom.hex(16) }

          response_status_should_be 401

          expect(json_response).to match(
            "error" => "invalid_token",
            "error_description" => an_instance_of(String),
            "state" => "unauthorized",
          )
        end
      end
    end

    context "when requested access token expired" do
      let(:token_for_introspection) do
        FactoryBot.create(:access_token, application: client, created_at: 1.year.ago)
      end

      it "responds with only active state" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match("active" => false)
      end
    end

    context "when requested Access Token revoked" do
      let(:token_for_introspection) do
        FactoryBot.create(:access_token, application: client, revoked_at: 1.year.ago)
      end

      it "responds with only active state" do
        request.headers["Authorization"] = basic_auth_header_for_client(client)

        post :introspect, params: { token: token_for_introspection.token }

        expect(json_response).to match("active" => false)
      end
    end

    context "when unauthorized (no bearer token or client credentials)" do
      let(:token_for_introspection) { FactoryBot.create(:access_token) }

      it "responds with invalid_request error" do
        post :introspect, params: { token: token_for_introspection.token }

        expect(response).not_to be_successful
        response_status_should_be 400

        expect(json_response).to match(
          "error" => "invalid_request",
          "error_description" => I18n.t("doorkeeper.errors.messages.invalid_request.request_not_authorized"),
        )
      end
    end
  end
end

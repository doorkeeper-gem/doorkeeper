# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::AuthorizationsController, "implicit grant flow" do
  include AuthorizationRequestHelper

  class ActionDispatch::TestResponse
    def query_params
      @query_params ||= begin
        fragment = URI.parse(location).fragment
        Rack::Utils.parse_query(fragment)
      end
    end
  end

  let(:client)        { FactoryBot.create :application }
  let(:user)          { User.create!(name: "Joe", password: "sekret") }
  let(:access_token)  { FactoryBot.build :access_token, resource_owner_id: user.id, application_id: client.id, scopes: "default" }

  before do
    Doorkeeper.configure do
      default_scopes :default

      custom_access_token_expires_in(lambda do |context|
        context.grant_type == Doorkeeper::OAuth::IMPLICIT ? 1234 : nil
      end)
    end

    allow(Doorkeeper.configuration).to receive(:grant_flows).and_return(["implicit"])
    allow(Doorkeeper.configuration).to receive(:authenticate_resource_owner).and_return(->(_) { authenticator_method })
    allow(controller).to receive(:authenticator_method).and_return(user)
    expect(controller).to receive(:authenticator_method).at_most(:once)
  end

  describe "POST #create" do
    before do
      post :create, params: { client_id: client.uid, response_type: "token", redirect_uri: client.redirect_uri }
    end

    it "redirects after authorization" do
      expect(response).to be_redirect
    end

    it "redirects to client redirect uri" do
      expect(response.location).to match(/^#{client.redirect_uri}/)
    end

    it "includes access token in fragment" do
      expect(response.query_params["access_token"]).to eq(Doorkeeper::AccessToken.first.token)
    end

    it "includes token type in fragment" do
      expect(response.query_params["token_type"]).to eq("Bearer")
    end

    it "includes token expiration in fragment" do
      expect(response.query_params["expires_in"].to_i).to eq(1234)
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe "POST #create in API mode" do
    before do
      allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)
      post :create, params: { client_id: client.uid, response_type: "token", redirect_uri: client.redirect_uri }
    end

    let(:response_json_body) { JSON.parse(response.body) }
    let(:redirect_uri) { response_json_body["redirect_uri"] }

    it "renders success after authorization" do
      expect(response).to be_successful
    end

    it "renders correct redirect uri" do
      expect(redirect_uri).to match(/^#{client.redirect_uri}/)
    end

    it "includes access token in fragment" do
      expect(redirect_uri.match(/access_token=([a-zA-Z0-9\-_]+)&?/)[1]).to eq(Doorkeeper::AccessToken.first.token)
    end

    it "includes token type in fragment" do
      expect(redirect_uri.match(/token_type=(\w+)&?/)[1]).to eq "Bearer"
    end

    it "includes token expiration in fragment" do
      expect(redirect_uri.match(/expires_in=(\d+)&?/)[1].to_i).to eq 1234
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe "POST #create with errors" do
    context "when missing client_id" do
      before do
        post :create, params: {
          client_id: "",
          response_type: "token",
          redirect_uri: client.redirect_uri,
        }
      end

      let(:response_json_body) { JSON.parse(response.body) }

      it "renders 400 error" do
        expect(response.status).to eq 400
      end

      it "includes error name" do
        expect(response_json_body["error"]).to eq("invalid_request")
      end

      it "includes error description" do
        expect(response_json_body["error_description"]).to eq(
          translated_invalid_request_error_message(:missing_param, :client_id)
        )
      end

      it "does not issue any access token" do
        expect(Doorkeeper::AccessToken.all).to be_empty
      end
    end

    context "when other error happens" do
      before do
        default_scopes_exist :public

        post :create, params: {
          client_id: client.uid,
          response_type: "token",
          scope: "invalid",
          redirect_uri: client.redirect_uri,
        }
      end

      it "redirects after authorization" do
        expect(response).to be_redirect
      end

      it "redirects to client redirect uri" do
        expect(response.location).to match(/^#{client.redirect_uri}/)
      end

      it "does not include access token in fragment" do
        expect(response.query_params["access_token"]).to be_nil
      end

      it "includes error in fragment" do
        expect(response.query_params["error"]).to eq("invalid_scope")
      end

      it "includes error description in fragment" do
        expect(response.query_params["error_description"]).to eq(translated_error_message(:invalid_scope))
      end

      it "does not issue any access token" do
        expect(Doorkeeper::AccessToken.all).to be_empty
      end
    end
  end

  describe "POST #create in API mode with errors" do
    context "when missing client_id" do
      before do
        allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)

        post :create, params: {
          client_id: "",
          response_type: "token",
          redirect_uri: client.redirect_uri,
        }
      end

      let(:response_json_body) { JSON.parse(response.body) }

      it "renders 400 error" do
        expect(response.status).to eq 400
      end

      it "includes error name" do
        expect(response_json_body["error"]).to eq("invalid_request")
      end

      it "includes error description" do
        expect(response_json_body["error_description"]).to eq(
          translated_invalid_request_error_message(:missing_param, :client_id)
        )
      end

      it "does not issue any access token" do
        expect(Doorkeeper::AccessToken.all).to be_empty
      end
    end

    context "when other error happens" do
      before do
        allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)
        default_scopes_exist :public

        post :create, params: {
          client_id: client.uid,
          response_type: "token",
          scope: "invalid",
          redirect_uri: client.redirect_uri,
        }
      end

      let(:response_json_body) { JSON.parse(response.body) }
      let(:redirect_uri) { response_json_body["redirect_uri"] }

      it "renders 400 error" do
        expect(response.status).to eq 400
      end

      it "includes correct redirect URI" do
        expect(redirect_uri).to match(/^#{client.redirect_uri}/)
      end

      it "does not include access token in fragment" do
        expect(redirect_uri.match(/access_token=([a-f0-9]+)&?/)).to be_nil
      end

      it "includes error in redirect uri" do
        expect(redirect_uri.match(/error=([a-z_]+)&?/)[1]).to eq "invalid_scope"
      end

      it "includes error description in redirect uri" do
        expect(redirect_uri.match(/error_description=(.+)&?/)[1]).to_not be_nil
      end

      it "does not issue any access token" do
        expect(Doorkeeper::AccessToken.all).to be_empty
      end
    end
  end

  describe "POST #create with application already authorized" do
    before do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)

      access_token.save!

      post :create, params: {
        client_id: client.uid,
        response_type: "token",
        redirect_uri: client.redirect_uri,
      }
    end

    it "returns the existing access token in a fragment" do
      expect(response.query_params["access_token"]).to eq(access_token.token)
    end

    it "does not creates a new access token" do
      expect(Doorkeeper::AccessToken.count).to eq(1)
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
          response_type: "token",
          redirect_uri: client.redirect_uri,
        }
      end

      it "should call :before_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:before_successful_authorization, :call).with(instance_of(described_class))
      end

      it "should call :after_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:after_successful_authorization, :call).with(instance_of(described_class))
      end
    end

    describe "with errors" do
      after do
        post :create, params: { client_id: client.uid, response_type: "token", redirect_uri: "bad_uri" }
      end

      it "should not call :before_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:before_successful_authorization)
      end

      it "should not call :after_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:after_successful_authorization)
      end
    end
  end

  describe "GET #new token request with native url and skip_authorization true" do
    before do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)

      client.update_attribute :redirect_uri, "urn:ietf:wg:oauth:2.0:oob"

      get :new, params: {
        client_id: client.uid,
        response_type: "token",
        redirect_uri: client.redirect_uri,
      }
    end

    it "should redirect immediately" do
      expect(response).to be_redirect
      expect(response.location).to match(%r{/oauth/token/info\?access_token=})
    end

    it "should not issue a grant" do
      expect(Doorkeeper::AccessGrant.count).to be 0
    end

    it "should issue a token" do
      expect(Doorkeeper::AccessToken.count).to be 1
    end
  end

  describe "GET #new code request with native url and skip_authorization true" do
    before do
      allow(Doorkeeper.configuration).to receive(:grant_flows).and_return(%w[authorization_code])
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)

      client.update_attribute :redirect_uri, "urn:ietf:wg:oauth:2.0:oob"

      get :new, params: {
        client_id: client.uid,
        response_type: "code",
        redirect_uri: client.redirect_uri,
      }
    end

    it "should redirect immediately" do
      expect(response).to be_redirect
      expect(response.location)
        .to match(%r{/oauth/authorize/native\?code=#{Doorkeeper::AccessGrant.first.token}})
    end

    it "should issue a grant" do
      expect(Doorkeeper::AccessGrant.count).to be 1
    end

    it "should not issue a token" do
      expect(Doorkeeper::AccessToken.count).to be 0
    end
  end

  describe "GET #new with skip_authorization true" do
    before do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)

      get :new, params: {
        client_id: client.uid,
        response_type: "token",
        redirect_uri: client.redirect_uri,
      }
    end

    it "should redirect immediately" do
      expect(response).to be_redirect
      expect(response.location).to match(/^#{client.redirect_uri}/)
    end

    it "should issue a token" do
      expect(Doorkeeper::AccessToken.count).to be 1
    end

    it "includes token type in fragment" do
      expect(response.query_params["token_type"]).to eq("Bearer")
    end

    it "includes token expiration in fragment" do
      expect(response.query_params["expires_in"].to_i).to eq(1234)
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe "GET #new in API mode" do
    before do
      allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)

      get :new, params: {
        client_id: client.uid,
        response_type: "token",
        redirect_uri: client.redirect_uri,
      }
    end

    it "should render success" do
      expect(response).to be_successful
    end

    it "sets status to pre-authorization" do
      expect(json_response["status"]).to eq(I18n.t("doorkeeper.pre_authorization.status"))
    end

    it "sets correct values" do
      expect(json_response["client_id"]).to eq(client.uid)
      expect(json_response["redirect_uri"]).to eq(client.redirect_uri)
      expect(json_response["state"]).to be_nil
      expect(json_response["response_type"]).to eq("token")
      expect(json_response["scope"]).to eq("default")
    end
  end

  describe "GET #new in API mode with skip_authorization true" do
    before do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc { true })
      allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)

      get :new, params: {
        client_id: client.uid,
        response_type: "token",
        redirect_uri: client.redirect_uri,
      }
    end

    it "should render success" do
      expect(response).to be_successful
    end

    it "should issue a token" do
      expect(Doorkeeper::AccessToken.count).to be 1
    end

    it "sets status to redirect" do
      expect(JSON.parse(response.body)["status"]).to eq("redirect")
    end

    it "sets redirect_uri to correct value" do
      redirect_uri = JSON.parse(response.body)["redirect_uri"]
      expect(redirect_uri).to_not be_nil
      expect(redirect_uri.match(/token_type=(\w+)&?/)[1]).to eq "Bearer"
      expect(redirect_uri.match(/expires_in=(\d+)&?/)[1].to_i).to eq 1234
      expect(
        redirect_uri.match(/access_token=([a-zA-Z0-9\-_]+)&?/)[1]
      ).to eq Doorkeeper::AccessToken.first.token
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe "GET #new with errors" do
    before do
      default_scopes_exist :public
      get :new, params: { an_invalid: "request" }
    end

    it "does not redirect" do
      expect(response).to_not be_redirect
    end

    it "does not issue any token" do
      expect(Doorkeeper::AccessGrant.count).to eq 0
      expect(Doorkeeper::AccessToken.count).to eq 0
    end
  end

  describe "GET #new in API mode with errors" do
    let(:response_json_body) { JSON.parse(response.body) }

    before do
      default_scopes_exist :public
      allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)
      get :new, params: { an_invalid: "request" }
    end

    it "should render bad request" do
      expect(response).to have_http_status(:bad_request)
    end

    it "includes error in body" do
      expect(response_json_body["error"]).to eq("invalid_request")
    end

    it "includes error description in body" do
      expect(response_json_body["error_description"])
        .to eq(translated_invalid_request_error_message(:missing_param, :client_id))
    end

    it "does not issue any token" do
      expect(Doorkeeper::AccessGrant.count).to eq 0
      expect(Doorkeeper::AccessToken.count).to eq 0
    end
  end

  describe "GET #new with callbacks" do
    after do
      client.update_attribute :redirect_uri, "urn:ietf:wg:oauth:2.0:oob"
      get :new, params: { client_id: client.uid, response_type: "token", redirect_uri: client.redirect_uri }
    end

    describe "when authorizing" do
      before do
        allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc { true })
      end

      it "should call :before_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:before_successful_authorization, :call).with(instance_of(described_class))
      end

      it "should call :after_successful_authorization callback" do
        expect(Doorkeeper.configuration)
          .to receive_message_chain(:after_successful_authorization, :call).with(instance_of(described_class))
      end
    end

    describe "when not authorizing" do
      before do
        allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc { false })
      end

      it "should not call :before_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:before_successful_authorization)
      end

      it "should not call :after_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:after_successful_authorization)
      end
    end

    describe "when not authorizing in api mode" do
      before do
        allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc { false })
        allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)
      end

      it "should not call :before_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:before_successful_authorization)
      end

      it "should not call :after_successful_authorization callback" do
        expect(Doorkeeper.configuration).not_to receive(:after_successful_authorization)
      end
    end
  end

  describe "authorize response memoization" do
    it "memoizes the result of the authorization" do
      pre_auth = double(:pre_auth, authorizable?: true)
      allow(controller).to receive(:pre_auth) { pre_auth }
      strategy = double(:strategy, authorize: true)
      expect(strategy).to receive(:authorize).once
      allow(controller).to receive(:strategy) { strategy }
      allow(controller).to receive(:create) do
        2.times { controller.send :authorize_response }
        controller.render json: {}, status: :ok
      end

      post :create
    end
  end

  describe "strong parameters" do
    it "ignores non-scalar scope parameter" do
      get :new, params: {
        client_id: client.uid,
        response_type: "token",
        redirect_uri: client.redirect_uri,
        scope: { "0" => "profile" },
      }

      expect(response).to be_successful
    end
  end
end

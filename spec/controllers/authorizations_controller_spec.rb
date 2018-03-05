require 'spec_helper_integration'

describe Doorkeeper::AuthorizationsController, 'implicit grant flow' do
  include AuthorizationRequestHelper

  if Rails::VERSION::MAJOR >= 5
    class ActionDispatch::TestResponse
      def query_params
        @_query_params ||= begin
          fragment = URI.parse(location).fragment
          Rack::Utils.parse_query(fragment)
        end
      end
    end
  else
    class ActionController::TestResponse
      def query_params
        @_query_params ||= begin
          fragment = URI.parse(location).fragment
          Rack::Utils.parse_query(fragment)
        end
      end
    end
  end

  def translated_error_message(key)
    I18n.translate key, scope: %i[doorkeeper errors messages]
  end

  let(:client)        { FactoryBot.create :application }
  let(:user)          { User.create!(name: 'Joe', password: 'sekret') }
  let(:access_token)  { FactoryBot.build :access_token, resource_owner_id: user.id, application_id: client.id }

  before do
    allow(Doorkeeper.configuration).to receive(:grant_flows).and_return(["implicit"])
    allow(controller).to receive(:current_resource_owner).and_return(user)
  end

  describe 'POST #create' do
    before do
      post :create, client_id: client.uid, response_type: 'token', redirect_uri: client.redirect_uri
    end

    it 'redirects after authorization' do
      expect(response).to be_redirect
    end

    it 'redirects to client redirect uri' do
      expect(response.location).to match(%r{^#{client.redirect_uri}})
    end

    it 'includes access token in fragment' do
      expect(response.query_params['access_token']).to eq(Doorkeeper::AccessToken.first.token)
    end

    it 'includes token type in fragment' do
      expect(response.query_params['token_type']).to eq('bearer')
    end

    it 'includes token expiration in fragment' do
      expect(response.query_params['expires_in'].to_i).to eq(2.hours.to_i)
    end

    it 'issues the token for the current client' do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it 'issues the token for the current resource owner' do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe "POST #create in API mode" do
    before do
      allow(Doorkeeper.configuration).to receive(:api_mode).and_return(true)
      post :create, client_id: client.uid, response_type: "token", redirect_uri: client.redirect_uri
    end

    let(:response_json_body) { JSON.parse(response.body) }
    let(:redirect_uri) { response_json_body["redirect_uri"] }

    it "renders success after authorization" do
      expect(response).to be_success
    end

    it "renders correct redirect uri" do
      expect(redirect_uri).to match(/^#{client.redirect_uri}/)
    end

    it "includes access token in fragment" do
      expect(redirect_uri.match(/access_token=([a-f0-9]+)&?/)[1]).to eq(Doorkeeper::AccessToken.first.token)
    end

    it "includes token type in fragment" do
      expect(redirect_uri.match(/token_type=(\w+)&?/)[1]).to eq "bearer"
    end

    it "includes token expiration in fragment" do
      expect(redirect_uri.match(/expires_in=(\d+)&?/)[1].to_i).to eq 2.hours
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe 'POST #create with errors' do
    before do
      default_scopes_exist :public
      post :create, client_id: client.uid, response_type: 'token', scope: 'invalid', redirect_uri: client.redirect_uri
    end

    it 'redirects after authorization' do
      expect(response).to be_redirect
    end

    it 'redirects to client redirect uri' do
      expect(response.location).to match(/^#{client.redirect_uri}/)
    end

    it 'does not include access token in fragment' do
      expect(response.query_params['access_token']).to be_nil
    end

    it 'includes error in fragment' do
      expect(response.query_params['error']).to eq('invalid_scope')
    end

    it 'includes error description in fragment' do
      expect(response.query_params['error_description']).to eq(translated_error_message(:invalid_scope))
    end

    it 'does not issue any access token' do
      expect(Doorkeeper::AccessToken.all).to be_empty
    end
  end

  describe 'POST #create in API mode with errors' do
    before do
      allow(Doorkeeper.configuration).to receive(:api_mode).and_return(true)
      default_scopes_exist :public
      post :create, client_id: client.uid, response_type: 'token', scope: 'invalid', redirect_uri: client.redirect_uri
    end
    let(:response_json_body) { JSON.parse(response.body) }
    let(:redirect_uri) { response_json_body['redirect_uri'] }

    it 'renders 400 error' do
      expect(response.status).to eq 401
    end

    it 'includes correct redirect URI' do
      expect(redirect_uri).to match(/^#{client.redirect_uri}/)
    end

    it 'does not include access token in fragment' do
      expect(redirect_uri.match(/access_token=([a-f0-9]+)&?/)).to be_nil
    end

    it 'includes error in redirect uri' do
      expect(redirect_uri.match(/error=([a-z_]+)&?/)[1]).to eq 'invalid_scope'
    end

    it 'includes error description in redirect uri' do
      expect(redirect_uri.match(/error_description=(.+)&?/)[1]).to_not be_nil
    end

    it 'does not issue any access token' do
      expect(Doorkeeper::AccessToken.all).to be_empty
    end
  end

  describe 'POST #create with application already authorized' do
    before do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)

      access_token.save!
      post :create, client_id: client.uid, response_type: 'token', redirect_uri: client.redirect_uri
    end

    it 'returns the existing access token in a fragment' do
      expect(response.query_params['access_token']).to eq(access_token.token)
    end

    it 'does not creates a new access token' do
      expect(Doorkeeper::AccessToken.count).to eq(1)
    end
  end

  describe 'GET #new token request with native url and skip_authorization true' do
    before do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)
      client.update_attribute :redirect_uri, 'urn:ietf:wg:oauth:2.0:oob'
      get :new, client_id: client.uid, response_type: 'token', redirect_uri: client.redirect_uri
    end

    it 'should redirect immediately' do
      expect(response).to be_redirect
      expect(response.location).to match(/oauth\/token\/info\?access_token=/)
    end

    it 'should not issue a grant' do
      expect(Doorkeeper::AccessGrant.count).to be 0
    end

    it 'should issue a token' do
      expect(Doorkeeper::AccessToken.count).to be 1
    end
  end

  describe 'GET #new code request with native url and skip_authorization true' do
    before do
      allow(Doorkeeper.configuration).to receive(:grant_flows).
        and_return(%w[authorization_code])
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)
      client.update_attribute :redirect_uri, 'urn:ietf:wg:oauth:2.0:oob'
      get :new, client_id: client.uid, response_type: 'code', redirect_uri: client.redirect_uri
    end

    it 'should redirect immediately' do
      expect(response).to be_redirect
      expect(response.location).to match(/oauth\/authorize\/native\?code=#{Doorkeeper::AccessGrant.first.token}/)
    end

    it 'should issue a grant' do
      expect(Doorkeeper::AccessGrant.count).to be 1
    end

    it 'should not issue a token' do
      expect(Doorkeeper::AccessToken.count).to be 0
    end
  end

  describe 'GET #new with skip_authorization true' do
    before do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)
      get :new, client_id: client.uid, response_type: 'token', redirect_uri: client.redirect_uri
    end

    it 'should redirect immediately' do
      expect(response).to be_redirect
      expect(response.location).to match(%r{^#{client.redirect_uri}})
    end

    it 'should issue a token' do
      expect(Doorkeeper::AccessToken.count).to be 1
    end

    it 'includes token type in fragment' do
      expect(response.query_params['token_type']).to eq('bearer')
    end

    it 'includes token expiration in fragment' do
      expect(response.query_params['expires_in'].to_i).to eq(2.hours.to_i)
    end

    it 'issues the token for the current client' do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it 'issues the token for the current resource owner' do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe 'GET #new in API mode with skip_authorization true' do
    before do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)
      allow(Doorkeeper.configuration).to receive(:api_mode).and_return(true)
      get :new, client_id: client.uid, response_type: 'token', redirect_uri: client.redirect_uri
    end

    it 'should render success' do
      expect(response).to be_success
    end

    it 'should issue a token' do
      expect(Doorkeeper::AccessToken.count).to be 1
    end

    it "sets status to redirect" do
      expect(JSON.parse(response.body)["status"]).to eq("redirect")
    end

    it "sets redirect_uri to correct value" do
      redirect_uri = JSON.parse(response.body)["redirect_uri"]
      expect(redirect_uri).to_not be_nil
      expect(redirect_uri.match(/token_type=(\w+)&?/)[1]).to eq "bearer"
      expect(redirect_uri.match(/expires_in=(\d+)&?/)[1].to_i).to eq 2.hours
      expect(
        redirect_uri.match(/access_token=([a-f0-9]+)&?/)[1]
      ).to eq Doorkeeper::AccessToken.first.token
    end

    it "issues the token for the current client" do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it "issues the token for the current resource owner" do
      expect(Doorkeeper::AccessToken.first.resource_owner_id).to eq(user.id)
    end
  end

  describe 'GET #new with errors' do
    before do
      default_scopes_exist :public
      get :new, an_invalid: 'request'
    end

    it 'does not redirect' do
      expect(response).to_not be_redirect
    end

    it 'does not issue any token' do
      expect(Doorkeeper::AccessGrant.count).to eq 0
      expect(Doorkeeper::AccessToken.count).to eq 0
    end
  end
end

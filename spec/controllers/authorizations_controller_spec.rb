require 'spec_helper_integration'

describe Doorkeeper::AuthorizationsController, 'implicit grant flow' do
  include AuthorizationRequestHelper

  def fragments(param)
    fragment = URI.parse(response.location).fragment
    Rack::Utils.parse_query(fragment)[param]
  end

  def translated_error_message(key)
    I18n.translate key, scope: [:doorkeeper, :errors, :messages]
  end

  let(:client) { FactoryGirl.create :application }
  let(:user)   { User.create!(name: 'Joe', password: 'sekret') }

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
      expect(fragments('access_token')).to eq(Doorkeeper::AccessToken.first.token)
    end

    it 'includes token type in fragment' do
      expect(fragments('token_type')).to eq('bearer')
    end

    it 'includes token expiration in fragment' do
      expect(fragments('expires_in').to_i).to eq(2.hours.to_i)
    end

    it 'issues the token for the current client' do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it 'issues the token for the current resource owner' do
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
      expect(response.location).to match(%r{^#{client.redirect_uri}})
    end

    it 'does not include access token in fragment' do
      expect(fragments('access_token')).to be_nil
    end

    it 'includes error in fragment' do
      expect(fragments('error')).to eq('invalid_scope')
    end

    it 'includes error description in fragment' do
      expect(fragments('error_description')).to eq(translated_error_message(:invalid_scope))
    end

    it 'does not issue any access token' do
      expect(Doorkeeper::AccessToken.all).to be_empty
    end
  end

  describe 'POST #create with application already authorized' do
    it 'returns the existing access token in a fragment'
  end

  describe 'GET #new' do
    before do
      get :new, client_id: client.uid, response_type: 'token', redirect_uri: client.redirect_uri
    end

    it 'renders new template' do
      expect(response).to render_template(:new)
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
        and_return(%w(authorization_code))
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(proc do
        true
      end)
      client.update_attribute :redirect_uri, 'urn:ietf:wg:oauth:2.0:oob'
      get :new, client_id: client.uid, response_type: 'code', redirect_uri: client.redirect_uri
    end

    it 'should redirect immediately' do
      expect(response).to be_redirect
      expect(response.location).to match(/oauth\/authorize\//)
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
      expect(fragments('token_type')).to eq('bearer')
    end

    it 'includes token expiration in fragment' do
      expect(fragments('expires_in').to_i).to eq(2.hours.to_i)
    end

    it 'issues the token for the current client' do
      expect(Doorkeeper::AccessToken.first.application_id).to eq(client.id)
    end

    it 'issues the token for the current resource owner' do
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

    it 'renders error template' do
      expect(response).to render_template(:error)
    end

    it 'does not issue any token' do
      expect(Doorkeeper::AccessGrant.count).to eq 0
      expect(Doorkeeper::AccessToken.count).to eq 0
    end
  end
end

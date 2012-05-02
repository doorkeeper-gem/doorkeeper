require 'spec_helper_integration'

describe Doorkeeper::AuthorizationsController, "implicit grant flow" do
  include AuthorizationRequestHelper

  def fragments(param)
    fragment = URI.parse(response.location).fragment
    Rack::Utils.parse_query(fragment)[param]
  end

  def translated_error_message(key)
    I18n.translate key, :scope => [:doorkeeper, :errors, :messages]
  end

  let(:client) { FactoryGirl.create :application }
  let(:user)   { User.create!(:name => "Joe", :password => "sekret") }

  before do
    controller.stub :current_resource_owner => user
  end

  describe "POST #create" do
    before do
      post :create, :client_id => client.uid, :response_type => "token", :redirect_uri => client.redirect_uri, :use_route => :doorkeeper
    end

    it "redirects after authorization" do
      response.should be_redirect
    end

    it "redirects to client redirect uri" do
      response.location.should =~ %r[^#{client.redirect_uri}]
    end

    it "includes access token in fragment" do
      fragments("access_token").should == Doorkeeper::AccessToken.first.token
    end

    it "includes token type in fragment" do
      fragments("token_type").should == "bearer"
    end

    it "includes token expiration in fragment" do
      fragments("expires_in").to_i.should == 2.hours.to_i
    end

    it "issues the token for the current client" do
      Doorkeeper::AccessToken.first.application_id.should == client.id
    end

    it "issues the token for the current resource owner" do
      Doorkeeper::AccessToken.first.resource_owner_id.should == user.id
    end
  end

  describe "POST #create with errors" do
    before do
      default_scopes_exist :public
      post :create, :client_id => client.uid, :response_type => "token", :scope => "invalid", :redirect_uri => client.redirect_uri, :use_route => :doorkeeper
    end

    it "redirects after authorization" do
      response.should be_redirect
    end

    it "redirects to client redirect uri" do
      response.location.should =~ %r[^#{client.redirect_uri}]
    end

    it "does not include access token in fragment" do
      fragments("access_token").should be_nil
    end

    it "includes error in fragment" do
      fragments("error").should == "invalid_scope"
    end

    it "includes error description in fragment" do
      fragments("error_description").should == translated_error_message(:invalid_scope)
    end

    it "does not issue any access token" do
      Doorkeeper::AccessToken.all.should be_empty
    end
  end

  describe "POST #create with application already authorized" do
    it "returns the existing access token in a fragment"
  end

  describe "GET #new" do
    before do
      get :new, :client_id => client.uid, :response_type => "token", :redirect_uri => client.redirect_uri, :use_route => :doorkeeper
    end

    it 'renders new template' do
      response.should render_template(:new)
    end
  end

  describe "GET #new with errors" do
    before do
      default_scopes_exist :public
      get :new, :client_id => client.uid, :response_type => "token", :scope => "invalid", :redirect_uri => client.redirect_uri, :use_route => :doorkeeper
    end

    it "redirects after authorization" do
      response.should be_redirect
    end

    it "redirects to client redirect uri" do
      response.location.should =~ %r[^#{client.redirect_uri}]
    end

    it "does not include access token in fragment" do
      fragments("access_token").should be_nil
    end

    it "includes error in fragment" do
      fragments("error").should == "invalid_scope"
    end

    it "includes error description in fragment" do
      fragments("error_description").should == translated_error_message(:invalid_scope)
    end

    it "does not issue any access token" do
      Doorkeeper::AccessToken.all.should be_empty
    end
  end
end

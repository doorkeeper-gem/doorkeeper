require 'spec_helper_integration'

describe Doorkeeper::AuthorizationsController do
  include Doorkeeper::OAuth
  include AuthorizationRequestHelper

  describe "when resource owner is not authenticated" do
    include_context "not authenticated resource owner"

    before { get :new, :use_route => :doorkeeper }

    it "get #new redirects to main app's root url" do
      should redirect_to(controller.main_app.root_url)
    end

    it "post #create redirects to main app's root url" do
      should redirect_to(controller.main_app.root_url)
    end
  end

  describe "#new" do
    include_context "authenticated resource owner"

    describe "when authorization is valid and no access token exists" do
      include_context "valid authorization request"

      before { authorization.stub(:access_token_exists? => false) }

      it "renders :new" do
        get :new, :use_route => :doorkeeper
        should render_template(:new)
      end
    end

    describe "when authorization is valid and an access token already exists" do
      include_context "valid authorization request"

      before { authorization.stub(:access_token_exists? => true) }

      it "renders :new" do
        get :new, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?code=token")
      end
    end

    describe "when authorization is not valid" do
      include_context "invalid authorization request"

      it "renders :error" do
        get :new, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end

  describe "#new with token response type" do
    before do
      @user   = User.create!
      resource_owner_is_authenticated @user
      client_exists
      scope_exist(:public, :default => true, :description => "Access your public data")
      scope_exist(:write, :description => "Update your data")
      @access_token = Factory :access_token, :application => @client, :resource_owner_id => @user.id
    end

    it "returns the existing access token in a fragment" do
      lambda {
        get :new, :client_id => @client.uid, :response_type => "token", :redirect_uri => @client.redirect_uri, :use_route => :doorkeeper
        response.should be_redirect
        uri = response.location
        fragment_params = parse_fragment_params(uri)
        fragment_params.should_not be_empty
        fragment_params["access_token"].should == @access_token.token
        fragment_params["expires_in"].should_not be_nil
        fragment_params["token_type"].should == "bearer"
      }.should_not change(AccessToken, :count).by(1)
    end

    it "returns an error in a fragment for an invalid request" do
      @access_token = Factory :access_token, :application => @client, :resource_owner_id => @user.id
      lambda {
        get :new, :client_id => @client.uid, :response_type => "token", :redirect_uri => @client.redirect_uri, :scope => "invalid", :use_route => :doorkeeper
        response.should be_redirect
        uri = response.location
        fragment_params = parse_fragment_params(uri)
        fragment_params.should_not be_empty
        fragment_params["error"].should == "invalid_scope"
        fragment_params["error_description"].should == (I18n.translate :invalid_scope, :scope => [:doorkeeper, :errors, :messages])
      }.should_not change(AccessToken, :count)
    end

  end

  describe "#create" do
    include_context "authenticated resource owner"

    describe "when authorization is valid" do
      include_context "valid authorization request"

      it "redirects to client's uri" do
        post :create, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?code=token")
      end
    end

    describe "when authorization is not valid" do
      include_context "invalid authorization request"

      it "renders :error" do
        post :create, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end

  describe "#create with token response type" do
    before do
      @user   = User.create!
      resource_owner_is_authenticated @user
      client_exists
      scope_exist(:public, :default => true, :description => "Access your public data")
      scope_exist(:write, :description => "Update your data")
    end

    it "creates a new access token and returns it in a fragment" do
      lambda {
        post :create, :client_id => @client.uid, :response_type => "token", :redirect_uri => @client.redirect_uri, :use_route => :doorkeeper
        response.should be_redirect
        uri = response.location
        fragment_params = parse_fragment_params(uri)
        fragment_params.should_not be_empty
        fragment_params["access_token"].should_not be_nil
        fragment_params["expires_in"].should_not be_nil
        fragment_params["token_type"].should == "bearer"
        }.should change(AccessToken, :count).by(1)
    end

    it "returns the existing access token in a fragment if a token exists" do
      @access_token = Factory :access_token, :application => @client, :resource_owner_id => @user.id
      lambda {
        post :create, :client_id => @client.uid, :response_type => "token", :redirect_uri => @client.redirect_uri, :use_route => :doorkeeper
        response.should be_redirect
        uri = response.location
        fragment_params = parse_fragment_params(uri)
        fragment_params.should_not be_empty
        fragment_params["access_token"].should == @access_token.token
        fragment_params["expires_in"].should_not be_nil
        fragment_params["token_type"].should == "bearer"
      }.should_not change(AccessToken, :count)
    end

    it "returns an error in a fragment for an invalid request" do
      @access_token = Factory :access_token, :application => @client, :resource_owner_id => @user.id
      lambda {
        post :create, :client_id => @client.uid, :response_type => "token", :redirect_uri => @client.redirect_uri, :scope => "invalid", :use_route => :doorkeeper
        response.should be_redirect
        uri = response.location
        fragment_params = parse_fragment_params(uri)
        fragment_params.should_not be_empty
        fragment_params["error"].should == "invalid_scope"
        fragment_params["error_description"].should == (I18n.translate :invalid_scope, :scope => [:doorkeeper, :errors, :messages])
      }.should_not change(AccessToken, :count)
    end

  end


  describe "#destroy" do
    include_context "authenticated resource owner"

    before do
      controller.stub(:authorization) do
        double(:authorization, :deny => true, :invalid_redirect_uri => "http://something.com/cb?error=access_denied")
      end
    end

    it "redirects to client's callback with error" do
      delete :destroy, :use_route => :doorkeeper
      should redirect_to("http://something.com/cb?error=access_denied")
    end
  end
end

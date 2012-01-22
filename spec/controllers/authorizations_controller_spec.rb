require 'spec_helper_integration'

describe Doorkeeper::AuthorizationsController do
  include Doorkeeper::OAuth
  include AuthorizationRequestHelper
  include ModelHelper

  describe "#new with token response type" do
    before do
      @user   = User.create!
      resource_owner_is_authenticated @user
      client_exists
      scope_exist(:public, :default => true, :description => "Access your public data")
      scope_exist(:write, :description => "Update your data")
      @access_token = Factory :access_token, :application => @client, :resource_owner_id => @user.id, :scopes => "public"
    end

    it "returns the existing access token in a fragment" do
      pending "It seems that authorization server should always issue a new token"
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
      pending "It seems that authorization server should always issue a new token"
      @access_token = Factory :access_token, :application => @client, :resource_owner_id => @user.id, :scopes => "public"
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
end

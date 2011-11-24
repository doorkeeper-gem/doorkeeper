require 'spec_helper'

describe SemiProtectedResourcesController do
  context "with token valid" do
    include_context "valid token"
    it "responds with success if token is passed as access_token param" do
      get :index, :access_token => token_string
      response.should be_success
    end

    it "responds with success if token is passed as bearer_token param" do
      get :index, :bearer_token => token_string
      response.should be_success
    end

    it "responds with success if token is passed in HTTP Authorization header" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
      get :index
      response.should be_success
    end
  end

  context "with token invalid" do
    include_context "invalid token"
    it "responds with unauthorized if token is passed as access_token param" do
      get :index, :access_token => token_string
      response.status.should == 401
    end

    it "responds with unauthorzied if token is passed as bearer_token param" do
      get :index, :bearer_token => token_string
      response.status.should == 401
    end

    it "responds with unauthorized if token is passed in HTTP Authorization header" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
      get :index
      response.status.should == 401
    end
  end

  context "for action that is excluded from doorkeeper" do
    it "response is success" do
      get :show, :id => "2"
      response.should be_success
    end
  end
end

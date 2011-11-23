require 'spec_helper'

describe FullProtectedResourcesController do
  context "with token valid" do
    include_context "valid token"

    it "allows execute index action" do
      get :index, :access_token => token_string
      response.should be_success
    end

    it "allows to execute show action" do
      get :index, :access_token => token_string
      response.should be_success
    end
  end

  context "with token invalid" do
    include_context "invalid token"

    it "does not allow to execute index action" do
      get :index, :access_token => token_string
      response.status.should == 401
    end

    it "does not allow to execute show action" do
      get :index, :access_token => token_string
      response.status.should == 401
    end
  end
end

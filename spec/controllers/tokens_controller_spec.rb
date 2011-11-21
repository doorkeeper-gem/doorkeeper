require "spec_helper"

module Doorkeeper
  describe TokensController do
    describe "when authorization has succeeded" do
      before do
        OAuth::AccessTokenRequest.any_instance.stub(:authorize).and_return(true)
        OAuth::AccessTokenRequest.any_instance.stub(:access_token).and_return("token")
        post :create, :use_route => :doorkeeper
      end

      it "includes access token in the response" do
        body = JSON.parse(response.body)
        body['access_token'].should_not be_nil
      end
    end
  end
end

require 'spec_helper_integration'

describe Doorkeeper::TokenInfoController do
  
  describe "when requesting tokeninfo with valid token" do

    let(:doorkeeper_token) { FactoryGirl.create(:access_token) }

    before(:each) do
      controller.stub(:doorkeeper_token) { doorkeeper_token }  
    end

    def do_get
      get :show
    end

    describe "successful request" do

      it "responds with tokeninfo" do
        do_get  
        response.body.should eq doorkeeper_token.to_json
      end

      it "responds with a 200 status" do
        do_get  
        response.status.should eq 200  
      end
    end

    describe "invalid token response" do
      before(:each) do
        controller.stub(:doorkeeper_token => nil)
      end
      it "responds with 401 when doorkeeper_token is not valid" do
        do_get
        response.status.should eq 401  
      end

      it "responds with 401 when doorkeeper_token is invalid, expired or revoked" do
        controller.stub(:doorkeeper_token => doorkeeper_token)
        doorkeeper_token.stub(:accessible? => false) 
        do_get
        response.status.should eq 401  
      end

      it "responds body message for error" do
        do_get
        response.body.should eq Doorkeeper::OAuth::ErrorResponse.new(:name => :invalid_request, :status => :unauthorized).attributes.to_json
      end
    end

  end

end

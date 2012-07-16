require 'spec_helper_integration'

describe Doorkeeper::TokensController do
  describe "when authorization has succeeded" do
    let :token do
      double(:token, :authorize => true)
    end

    before do
      controller.stub(:token) { token }
    end

    it "returns the authorization" do
      token.should_receive(:authorization)
      post :create
    end
  end

  describe "when authorization has failed" do
    let :token do
      double(:token, :authorize => false)
    end

    before do
      controller.stub(:token) { token }
    end

    it "returns the error response" do
      token.stub(:error_response => stub(:to_json => [], :status => :unauthorized))
      post :create
      response.status.should == 401
    end
  end

  describe "when requesting tokeninfo with valid token" do

    let(:doorkeeper_token) { FactoryGirl.create(:access_token) }

    before(:each) do
      controller.stub(:doorkeeper_token) { doorkeeper_token }  
    end

    def do_get
      get :tokeninfo
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
      it "responds with 401 when doorkeeper_token is not valid" do
        controller.stub(:doorkeeper_token => nil)
        do_get
        response.status.should eq 401  
      end

      it "responds with 401 when doorkeeper_token is not accessible" do
        doorkeeper_token.stub(:accessible? => false) 
        do_get
        response.status.should eq 401  
      end

      it "responds body message for error" do
        doorkeeper_token.stub(:accessible? => false) 
        do_get
        response.body.should eq Doorkeeper::OAuth::ErrorResponse.new(:name => :invalid_request, :status => :unauthorized).attributes.to_json
      end
    end

  end
end

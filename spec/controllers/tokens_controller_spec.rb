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
    require 'spec_helper'
    
    describe "successful request" do
      let(:doorkeeper_token) { Factory(:access_token) }

      before(:each) do
        controller.stub(:doorkeeper_token) { doorkeeper_token }  
      end

      def do_get
        get :tokeninfo
      end

      it "responds with tokeninfo" do
        do_get  
        response.body.should eq doorkeeper_token.to_json
      end

      it "responds with a 200 status" do
        do_get  
        response.status.should eq 200  
      end
    end

  end
end

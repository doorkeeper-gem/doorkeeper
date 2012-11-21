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
      pending 'verify need of these specs'
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
      pending 'verify need of these specs'
      token.stub(:error_response => stub(:to_json => [], :status => :unauthorized))
      post :create
      expect(response.status).to eq 401
    end
  end
end

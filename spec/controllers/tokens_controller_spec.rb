require 'spec_helper_integration'

describe Doorkeeper::TokensController do

  context "create" do
    describe "when authorization has succeeded" do
      let :token do
        double(:token, :authorize => true)
      end

      before do
        allow(controller).to receive(:token) { token }
      end

      it "returns the authorization" do
        pending 'verify need of these specs'
        expect(token).to receive(:authorization)
        post :create
      end
    end

    describe "when authorization has failed" do
      let :token do
        double(:token, :authorize => false)
      end

      before do
        allow(controller).to receive(:token) { token }
      end

      it "returns the error response" do
        pending 'verify need of these specs'
        allow(token).to receive(:error_response).and_return(double(:to_json => [], :status => :unauthorized))
        post :create
        expect(response.status).to eq 401
        expect(response.headers["WWW-Authenticate"]).to match(/Bearer/)
      end
    end
  end

  context "destroy" do

    describe "when token exists" do
      let :token do
        double(:token, :authorize => true)
      end

      before do
        controller.stub(:doorkeeper_token) { token }
        allow(controller).to receive(:token) { token }
      end

      it "revokes the token" do
        expect(token).to receive(:revoke)
        delete :destroy
        expect(response.status).to eq(204)
      end
    end

    describe "when token doesn't exist" do
      let :token do
        double(:token, :authorize => false)
      end

      before do
        controller.stub(:doorkeeper_token) { nil }
        allow(controller).to receive(:token) { token }
      end

      it "returns the error response" do
        expect(token).not_to receive(:revoke)
        delete :destroy
        expect(response.status).to eq(404)
      end
    end
  end

end

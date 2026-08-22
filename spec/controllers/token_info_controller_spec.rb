# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::TokenInfoController, type: :controller do
  render_views

  describe "when requesting token info with valid token" do
    let(:doorkeeper_token) { FactoryBot.create(:access_token) }

    describe "successful request" do
      it "responds with token info" do
        get :show, params: { access_token: doorkeeper_token.token }

        expect(response.body).to eq(doorkeeper_token.to_json)
      end

      it "responds with a 200 status" do
        get :show, params: { access_token: doorkeeper_token.token }

        expect(response.status).to eq 200
      end
    end

    describe "invalid token response" do
      it "responds with 401 when doorkeeper_token is not valid" do
        get :show

        expect(response.status).to eq 401
        expect(response.headers["WWW-Authenticate"]).to match(/^Bearer/)
      end

      it "responds with 401 when doorkeeper_token is invalid, expired or revoked" do
        allow(controller).to receive(:doorkeeper_token).and_return(doorkeeper_token)
        allow(doorkeeper_token).to receive(:accessible?).and_return(false)

        get :show

        expect(response.status).to eq 401
        expect(response.headers["WWW-Authenticate"]).to match(/^Bearer/)
      end

      it "responds body message for error" do
        get :show

        expect(response.body).to eq(
          Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json,
        )
      end
    end
  end

  context "when using dpop", token: :dpop do
    def build_dpop_proof(ath: Base64.urlsafe_encode64(Digest::SHA256.digest(token_string), padding: false),
                         htm: "GET",
                         htu: "http://test.host/oauth/token/info",
                         signing_key: self.signing_key)
      super
    end

    it "responds with token info for a valid dpop proof" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof
      get :show

      expect(response.status).to eq 200
      expect(response.body).to eq(token.to_json)
    end

    it "rejects an invalid dpop proof with incorrect request details" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(htu: "http://test.host/oauth/token")
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    it "rejects an invalid dpop proof with ath claim" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(ath: "X")
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    it "rejects an invalid dpop proof with mismatched public keys" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(signing_key: OpenSSL::PKey::EC.generate("prime256v1"))
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    it "rejects a dpop token received as a bearer token" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    it "rejects a bearer token received as a dpop token", token: :valid do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    it "rejects an empty dpop proof" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    it "rejects an unknown token presented via dpop with a bad proof as invalid_token" do
      allow(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(nil)

      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(htm: "X")
      get :show

      expect(response.status).to eq 401
      expect(response.body).to eq(Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json)
    end

    context "when dpop is not supported" do
      before do
        allow(Doorkeeper.config.access_token_model).to receive(:dpop_supported?).and_return(false)
      end

      it "responds with token info for a dpop-bound token presented as a bearer token" do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
        get :show

        expect(response.status).to eq 200
        expect(response.body).to eq(token.to_json)
      end
    end
  end
end

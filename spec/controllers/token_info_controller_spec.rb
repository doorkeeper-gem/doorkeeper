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

    # RFC 6750 §2 forbids transmitting the token by more than one method. On
    # this stable branch such a request fails closed as carrying no usable
    # token (401 invalid_token); the strict invalid_request (400) of §3.1
    # ships with 6.0.
    describe "multiple transmission methods" do
      it "responds with 401 when two methods present different tokens" do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{doorkeeper_token.token}"
        get :show, params: { access_token: "another-token" }

        expect(response.status).to eq 401
        expect(response.headers["WWW-Authenticate"]).to match(/^Bearer/)
      end

      it "responds with 401 when the same token is repeated across methods" do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{doorkeeper_token.token}"
        get :show, params: { access_token: doorkeeper_token.token }

        expect(response.status).to eq 401
        expect(response.headers["WWW-Authenticate"]).to match(/^Bearer/)
      end
    end
  end
end

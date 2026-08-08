# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ApplicationMetalController, type: :controller do
  render_views

  controller(described_class) do
    def index
      render json: {}, status: 200
    end

    def create
      render json: {}, status: 200
    end
  end

  # doorkeeper_token here resolves to Helpers::Controller#doorkeeper_token
  # rather than the Rails::Helpers one, so a subclass protected with
  # doorkeeper_authorize! — the shape of doorkeeper-openid_connect's
  # UserinfoController — relies on that helper keeping the token-or-nil
  # contract on a request that transmits the token by more than one method
  # (RFC 6750 §2): a raise would surface as an unhandled 500.
  describe "a subclass protected with doorkeeper_authorize!" do
    controller(described_class) do
      before_action :doorkeeper_authorize!

      def index
        render json: {}, status: 200
      end
    end

    let(:access_token) { FactoryBot.create(:access_token) }

    it "answers invalid_request (400) when the token is transmitted by more than one method" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{access_token.token}"
      get :index, params: { access_token: "another-token" }

      expect(response.status).to eq 400
      expect(response.headers["WWW-Authenticate"]).to include('error="invalid_request"')
    end

    it "keeps serving a request that transmits the token by a single method" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{access_token.token}"
      get :index

      expect(response.status).to eq 200
    end
  end

  it "lacks `helper_method` so the included hook becomes a no-op" do
    expect(described_class).not_to respond_to(:helper_method)
  end

  it "lazy run hooks" do
    i = 0
    ActiveSupport.on_load(:doorkeeper_metal_controller) { i += 1 }

    expect(i).to eq 1
  end

  describe "enforce_content_type" do
    before { allow(Doorkeeper.config).to receive(:enforce_content_type).and_return(flag) }

    context "when enabled" do
      let(:flag) { true }

      it "returns a 200 for the requests without body" do
        get :index, params: {}
        expect(response).to have_http_status :ok
      end

      it "returns a 200 for the requests with body and correct media type" do
        post :create, params: {}, as: :url_encoded_form
        expect(response).to have_http_status :ok
      end

      it "returns a 415 for the requests with body and incorrect media type" do
        post :create, params: {}, as: :json
        expect(response).to have_http_status :unsupported_media_type
      end
    end

    context "when disabled" do
      let(:flag) { false }

      it "returns a 200 for the correct media type" do
        get :index, as: :url_encoded_form
        expect(response).to have_http_status :ok
      end

      it "returns a 200 for an incorrect media type" do
        get :index, as: :json
        expect(response).to have_http_status :ok
      end

      it "returns a 200 for the requests with body and incorrect media type" do
        post :create, params: {}, as: :json
        expect(response).to have_http_status :ok
      end
    end
  end
end

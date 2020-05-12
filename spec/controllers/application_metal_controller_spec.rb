# frozen_string_literal: true

require "spec_helper_integration"

RSpec.describe Doorkeeper::ApplicationMetalController do
  controller(described_class) do
    def index
      render json: {}, status: 200
    end

    def create
      render json: {}, status: 200
    end
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
        expect(response).to have_http_status 200
      end

      it "returns a 200 for the requests with body and correct media type" do
        post :create, params: {}, as: :url_encoded_form
        expect(response).to have_http_status 200
      end

      it "returns a 415 for the requests with body and incorrect media type" do
        post :create, params: {}, as: :json
        expect(response).to have_http_status 415
      end
    end

    context "when disabled" do
      let(:flag) { false }

      it "returns a 200 for the correct media type" do
        get :index, as: :url_encoded_form
        expect(response).to have_http_status 200
      end

      it "returns a 200 for an incorrect media type" do
        get :index, as: :json
        expect(response).to have_http_status 200
      end

      it "returns a 200 for the requests with body and incorrect media type" do
        post :create, params: {}, as: :json
        expect(response).to have_http_status 200
      end
    end
  end
end

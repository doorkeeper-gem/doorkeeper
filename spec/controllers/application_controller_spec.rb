# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ApplicationController, type: :controller do
  # Same resolution as for ApplicationMetalController: doorkeeper_token comes
  # from Helpers::Controller, so a host controller inheriting from this class
  # and protected with doorkeeper_authorize! must see the refusal rendered
  # (RFC 6750 §3.1, invalid_request) rather than an unhandled raise.
  describe "a subclass protected with doorkeeper_authorize!" do
    controller(described_class) do
      before_action :doorkeeper_authorize!

      def index
        render plain: "index"
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
      expect(response.body).to eq "index"
    end
  end

  describe "current_resource_owner view helper" do
    controller(described_class) do
      def index
        render inline: "<%= current_resource_owner %>"
      end
    end

    it "is registered as a helper method" do
      expect(described_class._helper_methods).to include(:current_resource_owner)
    end

    it "is callable from views" do
      allow(controller).to receive(:current_resource_owner).and_return("owner-sentinel")

      get :index
      expect(response.body).to include("owner-sentinel")
    end
  end

  include_examples "enforcing proof of possession using dpop"
end

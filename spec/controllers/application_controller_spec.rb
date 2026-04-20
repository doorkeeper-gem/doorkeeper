# frozen_string_literal: true

require "spec_helper_integration"

RSpec.describe Doorkeeper::ApplicationController, type: :controller do
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
end

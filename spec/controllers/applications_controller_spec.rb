require 'spec_helper'

module Doorkeeper
  describe ApplicationsController do
    context "when admin is not authenticated" do
      before(:each) do
        Doorkeeper.configuration.stub(:authenticate_admin => proc do
          redirect_to main_app.root_path
        end)
      end

      it "redirects as set in Doorkeeper.authenticate_admin" do
        get :index, :use_route => :doorkeeper
        response.should redirect_to(controller.main_app.root_path)
      end
    end
  end
end

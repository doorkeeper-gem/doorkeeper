require 'spec_helper_integration'

module Doorkeeper
  describe ApplicationsController do
    context "when admin is not authenticated" do
      before(:each) do
        Doorkeeper.configuration.stub(:authenticate_admin => proc do
          redirect_to main_app.root_url
        end)
      end

      it "redirects as set in Doorkeeper.authenticate_admin" do
        get :index
        expect(response).to redirect_to(controller.main_app.root_url)
      end
    end
  end
end

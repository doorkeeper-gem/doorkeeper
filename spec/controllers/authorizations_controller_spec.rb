require "spec_helper"

module Doorkeeper
  describe AuthorizationsController, "when resource is not authenticated" do
    it "get #new redirects to main app's root url" do
      get :new, :use_route => :doorkeeper
      should redirect_to(controller.main_app.root_url)
    end

    it "post #create redirects to main app's root url" do
      post :create, :use_route => :doorkeeper
      should redirect_to(controller.main_app.root_url)
    end
  end

  describe AuthorizationsController, "#new" do
    before do
      controller.stub(:current_resource) { double(:resource, :id => 1) }
    end

    describe "when authorization is valid" do
      before { OAuth::AuthorizationRequest.any_instance.stub(:valid?) { true } }

      it "renders :new" do
        get :new, :use_route => :doorkeeper
        should render_template(:new)
      end
    end

    describe "when authorization is not valid" do
      it "renders :error" do
        OAuth::AuthorizationRequest.any_instance.stub(:valid?) { false }
        get :new, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end

  describe AuthorizationsController, "#create" do
    before do
      controller.stub(:current_resource) { double(:resource, :id => 1) }
      OAuth::AuthorizationRequest.any_instance.stub(:success_redirect_uri) { "http://something.com/cb?code=token" }
    end

    describe "when authorization is valid" do
      it "redirects to client's uri" do
        OAuth::AuthorizationRequest.any_instance.stub(:authorize) { true }
        post :create, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?code=token")
      end
    end

    describe "when authorization is not valid" do
      it "renders :error" do
        OAuth::AuthorizationRequest.any_instance.stub(:authorize) { false }
        post :create, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end
end

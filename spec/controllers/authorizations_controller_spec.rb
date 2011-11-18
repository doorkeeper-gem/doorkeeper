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

    describe "with valid params" do
      before { OAuth::AuthorizationRequest.any_instance.stub(:valid?) { true } }

      it "renders the :new template" do
        get :new, :use_route => :doorkeeper
        should render_template(:new)
      end
    end

    describe "with invalid params" do
      it "renders :error when params are invalid" do
        OAuth::AuthorizationRequest.any_instance.stub(:valid?) { false }
        get :new, :use_route => :doorkeeper
        should render_template(:error)
      end

      it "renders :error when params are invalid" do
        OAuth::AuthorizationRequest.any_instance.stub(:valid?) { raise OAuth::MismatchRedirectURI }
        get :new, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end

  describe AuthorizationsController, "#create" do
    let(:client) do
      double(:client, :uid => "randomstring", :redirect_uri => "http://something.com/cb")
    end

    before do
      controller.stub(:current_resource) { double(:resource, :id => 1) }
      OAuth::AuthorizationRequest.any_instance.stub(:client) { client }
      OAuth::AuthorizationRequest.any_instance.stub(:token)  { "token" }
    end

    describe "with valid params" do
      it "redirects to client's uri" do
        OAuth::AuthorizationRequest.any_instance.stub(:valid?) { true }
        post :create, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?code=token")
      end
    end

    describe "with invalid params" do
      it "renders :error when params are invalid" do
        OAuth::AuthorizationRequest.any_instance.stub(:valid?) { false }
        post :create, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?error=invalid_request")
      end

      it "renders :error when params are invalid" do
        OAuth::AuthorizationRequest.any_instance.stub(:valid?) { raise OAuth::MismatchRedirectURI }
        post :create, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end


end

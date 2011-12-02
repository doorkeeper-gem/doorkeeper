require "spec_helper"

describe Doorkeeper::AuthorizationsController do
  include Doorkeeper::OAuth

  describe "when resource owner is not authenticated" do
    include_context "not authenticated resource owner"

    before { get :new, :use_route => :doorkeeper }

    it "get #new redirects to main app's root url" do
      should redirect_to(controller.main_app.root_url)
    end

    it "post #create redirects to main app's root url" do
      should redirect_to(controller.main_app.root_url)
    end
  end

  describe "#new" do
    include_context "authenticated resource owner"

    describe "when authorization is valid and no access token exists" do
      include_context "valid authorization request"

      before { authorization.stub(:access_token_exists? => false) }

      it "renders :new" do
        get :new, :use_route => :doorkeeper
        should render_template(:new)
      end
    end

    describe "when authorization is valid and an access token already exists" do
      include_context "valid authorization request"

      before { authorization.stub(:access_token_exists? => true) }

      it "renders :new" do
        get :new, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?code=token")
      end
    end

    describe "when authorization is not valid" do
      include_context "invalid authorization request"

      it "renders :error" do
        get :new, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end

  describe "#create" do
    include_context "authenticated resource owner"

    describe "when authorization is valid" do
      include_context "valid authorization request"

      it "redirects to client's uri" do
        post :create, :use_route => :doorkeeper
        should redirect_to("http://something.com/cb?code=token")
      end
    end

    describe "when authorization is not valid" do
      include_context "invalid authorization request"

      it "renders :error" do
        post :create, :use_route => :doorkeeper
        should render_template(:error)
      end
    end
  end

  describe "#destroy" do
    include_context "authenticated resource owner"

    before do
      controller.stub(:authorization) do
        double(:authorization, :deny => true, :invalid_redirect_uri => "http://something.com/cb?error=access_denied")
      end
    end

    it "redirects to client's callback with error" do
      delete :destroy, :use_route => :doorkeeper
      should redirect_to("http://something.com/cb?error=access_denied")
    end
  end
end

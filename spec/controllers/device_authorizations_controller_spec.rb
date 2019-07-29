# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::DeviceAuthorizationsController do
  let(:resource_owner) { FactoryBot.create(:doorkeeper_testing_user, name: "Joe", password: "sekret") }
  let(:application) { FactoryBot.create(:application, owner_id: resource_owner.id) }
  let(:access_grant) { FactoryBot.create(:access_grant, user_code: "1234", application: application) }

  unless ENV["WITHOUT_DEVICE_CODE"]
    context "JSON API" do
      render_views

      before do
        resource_owner
        allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)
        allow(Doorkeeper.configuration).to receive(:authenticate_resource_owner).and_return(->(*) { User.first })
      end

      it "returns access grant info" do
        get :index, params: { format: :json }
        expect(response).to be_successful
        expect(response.status).to eq 204
      end

      it "returns access grant info" do
        get :show, params: { id: access_grant.user_code, format: :json }
        expect(response).to be_successful
        expect(json_response).to include("id", "resource_owner_id", "application_id", "expires_in", "redirect_uri",
                                         "scopes", "user_code")
      end

      it "returns correct grant values" do
        get :show, params: { id: access_grant.user_code, format: :json }
        expect(json_response["resource_owner_id"]).to eq access_grant.resource_owner_id
        expect(json_response["application_id"]).to eq application.id
        expect(json_response["expires_in"]).to eq access_grant.expires_in
        expect(json_response["redirect_uri"]).to eq access_grant.redirect_uri
        expect(json_response["scopes"]).to eq JSON.parse(access_grant.scopes.to_json)
        expect(json_response["user_code"]).to eq "1234"
      end

      it "redirects to user code input if user_code is wrong" do
        get :show, params: { id: "no-user-code", format: :json }
        expect(response).to be_unprocessable
        expect(json_response).to eq("errors" => "This user code is invalid")
      end

      it "redirects to user code input if user_code is expired" do
        access_grant.update! created_at: 10.minutes.ago
        get :show, params: { id: access_grant.user_code, format: :json }
        expect(response).to be_unprocessable
        expect(json_response).to eq("errors" => "This user code expired")
      end

      it "redirects to user code input if user_code is revoked" do
        access_grant.update! revoked_at: Time.now
        get :show, params: { id: access_grant.user_code, format: :json }
        expect(response).to be_unprocessable
        expect(json_response).to eq("errors" => "This user code was revoked")
      end

      it "updates access grant" do
        put :update, params: {
          id: access_grant.token,
          user_code: access_grant.user_code, format: :json,
        }
        access_grant.reload
        expect(access_grant.user_code).to eq nil
        expect(access_grant.revoked_at).to eq nil
        expect(access_grant.resource_owner_id).to eq resource_owner.id
        expect(json_response).to include("id", "resource_owner_id", "application_id", "expires_in", "redirect_uri",
                                         "scopes", "user_code")
      end

      it "update access grant with correct values" do
        put :update, params: {
          id: access_grant.token,
          user_code: access_grant.user_code, format: :json,
        }
        access_grant.reload
        expect(json_response["resource_owner_id"]).to eq access_grant.resource_owner_id
        expect(json_response["application_id"]).to eq application.id
        expect(json_response["expires_in"]).to eq access_grant.expires_in
        expect(json_response["redirect_uri"]).to eq access_grant.redirect_uri
        expect(json_response["scopes"]).to eq JSON.parse(access_grant.scopes.to_json)
        expect(json_response["user_code"]).to be_nil
      end

      it "returns validation errors on wrong update params" do
        put :update, params: {
          id: access_grant.token,
          doorkeeper_access_grant: { user_code: "wrong code" }, format: :json,
        }
        expect(response).to have_http_status(422)
        expect(json_response).to eq("errors" => "The user code is unknown or malformed.")
      end

      it "revokes an access grant" do
        delete :destroy, params: { id: access_grant.token, format: :json }
        expect(response).to have_http_status(204)
        expect(access_grant.reload.revoked_at).not_to be_nil
      end
    end

    context "when user is not authenticated" do
      before do
        access_grant
        allow(Doorkeeper.configuration).to receive(:authenticate_resource_owner).and_return(proc do
          redirect_to main_app.root_url
        end)
      end

      it "redirects verification uri to login, if not authenticated yet" do
        get :index
        expect(response).to redirect_to(controller.main_app.root_url)
      end

      it "redirects complete verification uri to login, if not authenticated yet" do
        get :show, params: { id: access_grant.user_code }
        expect(response).to redirect_to(controller.main_app.root_url)
      end

      it "redirects authorize action to login, if not authenticated yet" do
        put :update, params: {
          id: access_grant.token,
          user_code: access_grant.user_code,
        }
        expect(response).to redirect_to(controller.main_app.root_url)
      end
    end

    context "when user is authenticated" do
      render_views

      before do
        access_grant
        user = resource_owner
        allow(Doorkeeper.configuration).to receive(:authenticate_resource_owner).and_return(->(*) { user })
      end

      it "returns access grant info" do
        get :show, params: { id: access_grant.user_code }
        expect(response).to be_successful
        expect(response.body).to match(/You authorize the device Application \d+ with your user code, to access your account\./)
      end

      it "redirects to user code input if user_code is wrong" do
        get :show, params: { id: "no-user-code" }
        expect(response).to redirect_to(oauth_device_index_path)
        expect(flash["notice"]).to eq("This user code is invalid")
      end

      it "redirects to user code input if user_code is expired" do
        access_grant.update! created_at: 10.minutes.ago
        get :show, params: { id: access_grant.user_code }
        expect(response).to redirect_to(oauth_device_index_path)
        expect(flash["notice"]).to eq("This user code expired")
      end

      it "redirects to user code input if user_code is revoked" do
        access_grant.update! revoked_at: Time.now
        get :show, params: { id: access_grant.user_code }
        expect(response).to redirect_to(oauth_device_index_path)
        expect(flash["notice"]).to eq("This user code was revoked")
      end

      it "updates access grant" do
        put :update, params: {
          id: access_grant.token,
          user_code: access_grant.user_code,
        }
        access_grant.reload
        expect(access_grant.user_code).to eq nil
        expect(access_grant.revoked_at).to eq nil
        expect(access_grant.resource_owner_id).to eq resource_owner.id
        expect(response).to redirect_to(oauth_device_index_url)
      end

      it "revokes an access grant" do
        delete :destroy, params: { id: access_grant.token }
        expect(response).to redirect_to(oauth_device_index_url)
        expect(access_grant.reload.revoked_at).not_to be_nil
      end
    end
  end
end

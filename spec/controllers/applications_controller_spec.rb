# frozen_string_literal: true

require "spec_helper"

module Doorkeeper
  describe ApplicationsController do
    context "JSON API" do
      render_views

      before do
        allow(Doorkeeper.configuration).to receive(:api_only).and_return(true)
        allow(Doorkeeper.configuration).to receive(:authenticate_admin).and_return(->(*) { true })
      end

      it "creates an application" do
        expect do
          post :create, params: {
            doorkeeper_application: {
              name: "Example",
              redirect_uri: "https://example.com",
            }, format: :json,
          }
        end.to(change { Doorkeeper::Application.count })

        expect(response).to be_successful

        expect(json_response).to include("id", "name", "uid", "secret", "redirect_uri", "scopes")

        expect(json_response["name"]).to eq("Example")
        expect(json_response["redirect_uri"]).to eq("https://example.com")
      end

      it "returns validation errors on wrong create params" do
        expect do
          post :create, params: {
            doorkeeper_application: {
              name: "Example",
            }, format: :json,
          }
        end.not_to(change { Doorkeeper::Application.count })

        expect(response).to have_http_status(422)

        expect(json_response).to include("errors")
      end

      it "returns application info" do
        application = FactoryBot.create(:application, name: "Change me")

        get :show, params: { id: application.id, format: :json }

        expect(response).to be_successful

        expect(json_response).to include("id", "name", "uid", "secret", "redirect_uri", "scopes")
      end

      it "updates application" do
        application = FactoryBot.create(:application, name: "Change me")

        put :update, params: {
          id: application.id,
          doorkeeper_application: {
            name: "Example App",
            redirect_uri: "https://example.com",
          }, format: :json,
        }

        expect(application.reload.name).to eq "Example App"

        expect(json_response).to include("id", "name", "uid", "secret", "redirect_uri", "scopes")
      end

      it "returns validation errors on wrong update params" do
        application = FactoryBot.create(:application, name: "Change me")

        put :update, params: {
          id: application.id,
          doorkeeper_application: {
            name: "Example App",
            redirect_uri: "localhost:3000",
          }, format: :json,
        }

        expect(response).to have_http_status(422)

        expect(json_response).to include("errors")
      end

      it "destroys an application" do
        application = FactoryBot.create(:application)

        delete :destroy, params: { id: application.id, format: :json }

        expect(response).to have_http_status(204)
        expect(Application.count).to be_zero
      end
    end

    context "when admin is not authenticated" do
      before do
        allow(Doorkeeper.configuration).to receive(:authenticate_admin).and_return(proc do
          redirect_to main_app.root_url
        end)
      end

      it "redirects as set in Doorkeeper.authenticate_admin" do
        get :index
        expect(response).to redirect_to(controller.main_app.root_url)
      end

      it "does not create application" do
        expect do
          post :create, params: {
            doorkeeper_application: {
              name: "Example",
              redirect_uri: "https://example.com",
            },
          }
        end.not_to(change { Doorkeeper::Application.count })
      end
    end

    context "when admin is authenticated" do
      render_views

      before do
        allow(Doorkeeper.configuration).to receive(:authenticate_admin).and_return(->(*) { true })
      end

      it "sorts applications by created_at" do
        first_application = FactoryBot.create(:application)
        second_application = FactoryBot.create(:application)
        expect(Doorkeeper::Application).to receive(:ordered_by).and_call_original

        get :index

        expect(response.body).to have_selector("tbody tr:first-child#application_#{first_application.id}")
        expect(response.body).to have_selector("tbody tr:last-child#application_#{second_application.id}")
      end

      it "creates application" do
        expect do
          post :create, params: {
            doorkeeper_application: {
              name: "Example",
              redirect_uri: "https://example.com",
            },
          }
        end.to change { Doorkeeper::Application.count }.by(1)

        expect(response).to be_redirect
      end

      it "does not allow mass assignment of uid or secret" do
        application = FactoryBot.create(:application)
        put :update, params: {
          id: application.id,
          doorkeeper_application: {
            uid: "1A2B3C4D",
            secret: "1A2B3C4D",
          },
        }

        expect(application.reload.uid).not_to eq "1A2B3C4D"
      end

      it "updates application" do
        application = FactoryBot.create(:application)
        put :update, params: {
          id: application.id, doorkeeper_application: {
            name: "Example",
            redirect_uri: "https://example.com",
          },
        }

        expect(application.reload.name).to eq "Example"
      end
    end
  end
end

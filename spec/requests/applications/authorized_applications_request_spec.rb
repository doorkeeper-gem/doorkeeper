# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Authorized applications endpoint", type: :request do
  let(:application) { FactoryBot.create(:application) }

  # A token with no resource owner at all — what the client credentials flow
  # issues. It is the record a nil `current_resource_owner` scopes to.
  let!(:clientless_owner_token) do
    FactoryBot.create(:access_token, application: application, resource_owner_id: nil)
  end

  context "when the resource owner authenticator answers nil" do
    before do
      config_is_set(:authenticate_resource_owner) { nil }
    end

    it "refuses to list applications" do
      get "/oauth/authorized_applications.json"

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to be_empty
    end

    it "refuses to revoke tokens and leaves them alone" do
      delete "/oauth/authorized_applications/#{application.id}.json"

      expect(response).to have_http_status(:unauthorized)
      expect(clientless_owner_token.reload.revoked_at).to be_nil
    end

    it "refuses the HTML requests too" do
      get "/oauth/authorized_applications"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # The suite resets the configuration before every example, so no block is
  # configured here and Doorkeeper's own default one runs: it warns that the
  # authenticator is not configured and answers nil.
  context "with the default resource owner authenticator" do
    it "refuses to list applications" do
      expect(Rails.logger).to receive(:warn).at_least(:once)

      get "/oauth/authorized_applications.json"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Doorkeeper::ApplicationController picks its superclass when its class body
  # is evaluated, so the real API-only hierarchy has to be rebuilt in process.
  # See spec/requests/applications/api_only_spec.rb for why the sources are
  # eval'd under a file name of their own rather than `load`ed.
  context "with api_only mode enabled" do
    before do
      allow(Doorkeeper.config).to receive(:api_only).and_return(true)
      config_is_set(:authenticate_resource_owner) { nil }

      stub_const("Doorkeeper::ApplicationController", Class.new(ActionController::API))
      stub_const(
        "Doorkeeper::AuthorizedApplicationsController",
        Class.new(Doorkeeper::ApplicationController),
      )

      %w[application_controller authorized_applications_controller].each do |file|
        path = Doorkeeper::Engine.root.join("app", "controllers", "doorkeeper", "#{file}.rb").to_s
        eval(File.read(path), TOPLEVEL_BINDING, "#{path} (api_only authorized)") # rubocop:disable Security/Eval
      end
    end

    it "refuses to list applications" do
      get "/oauth/authorized_applications", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses to revoke tokens and leaves them alone" do
      delete "/oauth/authorized_applications/#{application.id}", as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(clientless_owner_token.reload.revoked_at).to be_nil
    end
  end

  context "when the resource owner authenticator answers a user" do
    let(:user) { User.create!(name: "Joe", password: "sekret") }
    let!(:token) do
      FactoryBot.create(:access_token, application: application, resource_owner_id: user.id)
    end

    before do
      resource_owner_is_authenticated(user)
    end

    it "lists the applications authorized for that user" do
      get "/oauth/authorized_applications.json"

      expect(response).to have_http_status(:ok)
      expect(json_response.map { |app| app["id"] }).to eq([application.id])
    end

    it "revokes that user's tokens" do
      delete "/oauth/authorized_applications/#{application.id}.json"

      expect(response).to have_http_status(:no_content)
      expect(token.reload.revoked_at).not_to be_nil
    end

    it "leaves tokens that have no resource owner alone" do
      delete "/oauth/authorized_applications/#{application.id}.json"

      expect(clientless_owner_token.reload.revoked_at).to be_nil
    end
  end
end

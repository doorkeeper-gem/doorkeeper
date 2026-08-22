# frozen_string_literal: true

require "spec_helper"

# Doorkeeper::ApplicationController picks its superclass (ActionController::API
# vs ActionController::Base) when its class body is evaluated, so stubbing
# `api_only` after boot still leaves the ActionController::Base hierarchy in
# place, where `flash` exists. To exercise the real API-only hierarchy
# in-process, these specs stub the controller constants with bare
# ActionController::API subclasses and re-evaluate the real controller sources
# into them (reopening the stubbed constants, whose superclasses match what
# `resolve_controller` returns while `api_only` is stubbed). rspec-mocks
# restores the original controllers after each example.
#
# The sources are evaluated under a file name of their own rather than
# `load`ed. Coverage is recorded per file name and attached to the code as
# compiled: `load` would compile the real file again, and every method the
# other examples run — the ones of the original controllers — would keep
# counting into an array the report no longer reads, so the controllers'
# coverage would depend on which examples happened to run after this file.
RSpec.describe "Doorkeeper::ApplicationsController in api_only mode", type: :request do
  before do
    allow(Doorkeeper.config).to receive_messages(
      api_only: true,
      authenticate_admin: ->(*) { true },
    )

    stub_const("Doorkeeper::ApplicationController", Class.new(ActionController::API))
    stub_const("Doorkeeper::ApplicationsController", Class.new(Doorkeeper::ApplicationController))

    %w[application_controller applications_controller].each do |file|
      path = Doorkeeper::Engine.root.join("app", "controllers", "doorkeeper", "#{file}.rb").to_s
      eval(File.read(path), TOPLEVEL_BINDING, "#{path} (api_only)") # rubocop:disable Security/Eval
    end
  end

  it "inherits from ActionController::API" do
    expect(Doorkeeper::ApplicationController.superclass).to eq(ActionController::API)
  end

  it "creates an application" do
    expect do
      post "/oauth/applications",
           params: {
             doorkeeper_application: {
               name: "Example",
               redirect_uri: "https://example.com",
             },
           },
           as: :json
    end.to change { Doorkeeper::Application.count }.by(1)

    expect(response).to be_successful
  end

  it "updates an application" do
    application = FactoryBot.create(:application, name: "Change me")

    put "/oauth/applications/#{application.id}",
        params: { doorkeeper_application: { name: "Example App" } },
        as: :json

    expect(response).to be_successful
    expect(application.reload.name).to eq("Example App")
  end

  it "destroys an application" do
    application = FactoryBot.create(:application)

    delete "/oauth/applications/#{application.id}", as: :json

    expect(response).to have_http_status(:no_content)
    expect(Doorkeeper::Application.count).to be_zero
  end

  # The examples above name the format, which is not what a client does by
  # default. An absent Accept header and a browser-like list such as
  # "application/json, text/plain, */*" (axios's default) both resolve to
  # text/html, and a bare "*/*" (curl, Net::HTTP, python-requests) resolves to
  # Mime::ALL, which respond_to answers with the first registered format —
  # html in every action here. These are the requests that used to reach the
  # html branch and raise on flash after the record had already been written.
  {
    "an absent Accept header" => nil,
    "a browser-like Accept list" => "application/json, text/plain, */*",
    "a wildcard Accept header" => "*/*",
  }.each do |description, accept|
    context "with #{description}" do
      let(:headers) { accept ? { "Accept" => accept } : {} }

      it "creates an application and answers with JSON" do
        expect do
          post "/oauth/applications",
               params: {
                 doorkeeper_application: {
                   name: "Example",
                   redirect_uri: "https://example.com",
                 },
               },
               headers: headers
        end.to change { Doorkeeper::Application.count }.by(1)

        expect(response).to be_successful
        expect(response.media_type).to eq("application/json")
      end

      it "updates an application and answers with JSON" do
        application = FactoryBot.create(:application, name: "Change me")

        put "/oauth/applications/#{application.id}",
            params: { doorkeeper_application: { name: "Example App" } },
            headers: headers

        expect(response).to be_successful
        expect(response.media_type).to eq("application/json")
        expect(application.reload.name).to eq("Example App")
      end

      it "destroys an application" do
        application = FactoryBot.create(:application)

        delete "/oauth/applications/#{application.id}", headers: headers

        expect(response).to have_http_status(:no_content)
        expect(Doorkeeper::Application.count).to be_zero
      end
    end
  end
end

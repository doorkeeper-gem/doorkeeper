# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Scoped routes" do
  before :all do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      allow_token_introspection false
    end

    Rails.application.routes.disable_clear_and_finalize = true

    Rails.application.routes.draw do
      use_doorkeeper scope: "scope"
    end
  end

  after :all do
    Rails.application.routes.clear!

    load File.expand_path("../dummy/config/routes.rb", __dir__)
  end

  it "GET /scope/authorize routes to authorizations controller" do
    expect(get("/scope/authorize")).to route_to("doorkeeper/authorizations#new")
  end

  it "POST /scope/authorize routes to authorizations controller" do
    expect(post("/scope/authorize")).to route_to("doorkeeper/authorizations#create")
  end

  it "DELETE /scope/authorize routes to authorizations controller" do
    expect(delete("/scope/authorize")).to route_to("doorkeeper/authorizations#destroy")
  end

  it "POST /scope/token routes to tokens controller" do
    expect(post("/scope/token")).to route_to("doorkeeper/tokens#create")
  end

  it "GET /scope/applications routes to applications controller" do
    expect(get("/scope/applications")).to route_to("doorkeeper/applications#index")
  end

  it "GET /scope/authorized_applications routes to authorized applications controller" do
    expect(get("/scope/authorized_applications")).to route_to("doorkeeper/authorized_applications#index")
  end

  it "GET /scope/token/info route to authorized TokenInfo controller" do
    expect(get("/scope/token/info")).to route_to("doorkeeper/token_info#show")
  end

  it "POST /scope/introspect routes not to exist" do
    expect(post("/scope/introspect")).not_to be_routable
  end

  it "GET /.well-known/oauth-authorization-server route to show Discovery controller" do
    expect(get("/.well-known/oauth-authorization-server")).to route_to("doorkeeper/discovery#show")
  end
end

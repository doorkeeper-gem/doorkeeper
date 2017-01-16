# frozen_string_literal: true
require "spec_helper_integration"

describe "routes for an api_only option" do
  it "GET /api_only/oauth/authorize routes to authorizations controller" do
    expect(get("/api_only/oauth/authorize")).to(
      route_to("doorkeeper/authorizations#new")
    )
  end

  it "POST /api_only/oauth/authorize routes to authorizations controller" do
    expect(post("/api_only/oauth/authorize")).to(
      route_to("doorkeeper/authorizations#create")
    )
  end

  it "DELETE /api_only/oauth/authorize routes to authorizations controller" do
    expect(delete("/api_only/oauth/authorize")).to(
      route_to("doorkeeper/authorizations#destroy")
    )
  end

  it "POST /api_only/oauth/token routes to tokens controller" do
    expect(post("/api_only/oauth/token")).to(
      route_to("doorkeeper/tokens#create")
    )
  end

  it "POST /api_only/oauth/revoke routes to tokens controller" do
    expect(post("/api_only/oauth/revoke")).to(
      route_to("doorkeeper/tokens#revoke")
    )
  end

  it "GET /api_only/oauth/applications routes to applications controller" do
    expect(get("/api_only/oauth/applications")).not_to be_routable
  end

  it "GET /api_only/oauth/authorized_applications routes to
      authorized applications controller" do
    expect(get("/api_only/oauth/authorized_applications")).not_to be_routable
  end

  it "GET /api_only/oauth/token/info route to authorzed tokeninfo controller" do
    expect(get("/api_only/oauth/token/info")).to(
      route_to("doorkeeper/token_info#show")
    )
  end
end

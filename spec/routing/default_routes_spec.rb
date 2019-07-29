# frozen_string_literal: true

require "spec_helper"

describe "Default routes" do
  it "GET /oauth/authorize routes to authorizations controller" do
    expect(get("/oauth/authorize")).to route_to("doorkeeper/authorizations#new")
  end

  it "POST /oauth/authorize routes to authorizations controller" do
    expect(post("/oauth/authorize")).to route_to("doorkeeper/authorizations#create")
  end

  it "DELETE /oauth/authorize routes to authorizations controller" do
    expect(delete("/oauth/authorize")).to route_to("doorkeeper/authorizations#destroy")
  end

  it "POST /oauth/token routes to tokens controller" do
    expect(post("/oauth/token")).to route_to("doorkeeper/tokens#create")
  end

  it "POST /oauth/revoke routes to tokens controller" do
    expect(post("/oauth/revoke")).to route_to("doorkeeper/tokens#revoke")
  end

  it "POST /oauth/introspect routes to tokens controller" do
    expect(post("/oauth/introspect")).to route_to("doorkeeper/tokens#introspect")
  end

  it "GET /oauth/applications routes to applications controller" do
    expect(get("/oauth/applications")).to route_to("doorkeeper/applications#index")
  end

  it "GET /oauth/authorized_applications routes to authorized applications controller" do
    expect(get("/oauth/authorized_applications")).to route_to("doorkeeper/authorized_applications#index")
  end

  it "GET /oauth/token/info route to authorized TokenInfo controller" do
    expect(get("/oauth/token/info")).to route_to("doorkeeper/token_info#show")
  end

  it "POST /oauth/authorize_device routes to device authorizations controller" do
    expect(post("/oauth/authorize_device")).to route_to("doorkeeper/device_codes#create")
  end

  it "GET /oauth/device routes to authorizations controller" do
    expect(get("/oauth/device")).to route_to("doorkeeper/device_authorizations#index")
  end

  it "GET /oauth/device/:user_code routes to authorizations controller" do
    expect(get("/oauth/device/123456")).to route_to("doorkeeper/device_authorizations#show", id: "123456")
  end

  it "PATCH /oauth/device routes to authorizations controller" do
    expect(patch("/oauth/device/123456")).to route_to("doorkeeper/device_authorizations#update", id: "123456")
  end

  it "DELETE /oauth/device routes to authorizations controller" do
    expect(delete("/oauth/device/123456")).to route_to("doorkeeper/device_authorizations#destroy", id: "123456")
  end
end

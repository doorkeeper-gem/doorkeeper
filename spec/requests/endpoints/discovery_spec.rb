# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Discovery endpoint" do
  it "returns json" do
    get "/.well-known/oauth-authorization-server"

    response_status_should_be(200)

    # WIP: currently empty
    expect(json_response).to eq({})
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ActionController::Metal API" do
  before do
    @client   = FactoryBot.create(:application)
    @resource = User.create!(name: "Joe", password: "sekret")
    @token    = client_is_authorized(@client, @resource)
  end

  it "client requests protected resource with valid token" do
    get "/metal.json?access_token=#{@token.token}"
    expect(json_response).to include("ok" => true)
  end
end

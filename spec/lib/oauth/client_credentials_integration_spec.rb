# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::OAuth::ClientCredentialsRequest do
  let(:server) { Doorkeeper.configuration }

  context "with a valid request" do
    let(:client) { Doorkeeper::OAuth::Client.new(FactoryBot.build_stubbed(:application)) }

    it "issues an access token" do
      request = Doorkeeper::OAuth::ClientCredentialsRequest.new(server, client, {})
      expect do
        request.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end
  end

  describe "with an invalid request" do
    it "does not issue an access token" do
      request = Doorkeeper::OAuth::ClientCredentialsRequest.new(server, nil, {})
      expect do
        request.authorize
      end.to_not(change { Doorkeeper::AccessToken.count })
    end
  end
end

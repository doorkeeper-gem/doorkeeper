# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::CodeRequest do
  subject(:request) do
    described_class.new(pre_auth, owner)
  end

  let(:pre_auth) do
    allow(Doorkeeper.config)
      .to receive(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))
    allow(Doorkeeper.config)
      .to receive(:grant_flows).and_return(Doorkeeper::OAuth::Scopes.from_string("authorization_code"))

    application = FactoryBot.create(:application, scopes: "public")
    client = Doorkeeper::OAuth::Client.new(application)

    attributes = {
      client_id: client.uid,
      response_type: "code",
      redirect_uri: "https://app.com/callback",
    }

    pre_auth = Doorkeeper::OAuth::PreAuthorization.new(Doorkeeper.config, attributes)
    pre_auth.authorizable?
    pre_auth
  end

  let(:owner) { FactoryBot.create(:resource_owner) }

  context "when pre_auth is authorized" do
    it "creates an access grant and returns a code response" do
      expect { request.authorize }.to change { Doorkeeper::AccessGrant.count }.by(1)
      expect(request.authorize).to be_a(Doorkeeper::OAuth::CodeResponse)
    end
  end

  context "when pre_auth is denied" do
    it "does not create access grant and returns a error response" do
      expect { request.deny }.not_to(change { Doorkeeper::AccessGrant.count })
      expect(request.deny).to be_a(Doorkeeper::OAuth::ErrorResponse)
    end
  end
end

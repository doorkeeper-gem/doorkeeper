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

    params = {
      client_id: client.uid,
      response_type: "code",
      redirect_uri: "https://app.com/callback",
      response_mode: response_mode,
    }.compact

    pre_auth = Doorkeeper::OAuth::PreAuthorization.new(params)
    pre_auth.authorizable?
    pre_auth
  end

  let(:response_mode) { nil }
  let(:owner) { FactoryBot.create(:resource_owner) }

  context "when pre_auth is authorized" do
    it "creates an access grant and returns a code response" do
      expect { request.authorize }.to change { Doorkeeper::AccessGrant.count }.by(1)
      expect(request.authorize).to be_a(Doorkeeper::OAuth::CodeResponse)
      expect(request.authorize.response_on_fragment).to be false
    end

    context "with 'fragment' as response_mode" do
      let(:response_mode) { "fragment" }

      it "returns a code response with response_on_fragment set to true" do
        expect(request.authorize.response_on_fragment).to be true
      end
    end
  end

  context "when pre_auth is denied" do
    it "does not create access grant and returns a error response" do
      expect { request.deny }.not_to(change { Doorkeeper::AccessGrant.count })
      expect(request.deny).to be_a(Doorkeeper::OAuth::ErrorResponse)
    end
  end
end

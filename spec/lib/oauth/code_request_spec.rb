# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::OAuth::CodeRequest do
  let(:pre_auth) do
    server = Doorkeeper.configuration
    allow(server)
      .to receive(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))
    allow(server)
      .to receive(:grant_flows).and_return(Doorkeeper::OAuth::Scopes.from_string("authorization_code"))

    application = FactoryBot.create(:application, scopes: "public")
    client = Doorkeeper::OAuth::Client.new(application)

    attributes = {
      client_id: client.uid,
      response_type: "code",
      redirect_uri: "https://app.com/callback",
    }

    pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, attributes)
    pre_auth.authorizable?
    pre_auth
  end

  let(:owner) { double :owner, id: 8900 }

  subject do
    described_class.new(pre_auth, owner)
  end

  context "when pre_auth is authorized" do
    it "creates an access grant and returns a code response" do
      expect { subject.authorize }.to change { Doorkeeper::AccessGrant.count }.by(1)
      expect(subject.authorize).to be_a(Doorkeeper::OAuth::CodeResponse)
    end
  end

  context "when pre_auth is denied" do
    it "does not create access grant and returns a error response" do
      expect { subject.deny }.not_to(change { Doorkeeper::AccessGrant.count })
      expect(subject.deny).to be_a(Doorkeeper::OAuth::ErrorResponse)
    end
  end
end

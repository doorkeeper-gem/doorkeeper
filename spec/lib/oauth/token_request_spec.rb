# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::OAuth::TokenRequest do
  let :application do
    FactoryBot.create(:application, scopes: "public")
  end

  let :pre_auth do
    server = Doorkeeper.config
    allow(server).to receive(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public"))
    allow(server).to receive(:grant_flows).and_return(Doorkeeper::OAuth::Scopes.from_string("implicit"))

    client = Doorkeeper::OAuth::Client.new(application)

    attributes = {
      client_id: client.uid,
      response_type: "token",
      redirect_uri: "https://app.com/callback",
    }

    pre_auth = Doorkeeper::OAuth::PreAuthorization.new(server, attributes)
    pre_auth.authorizable?
    pre_auth
  end

  let :owner do
    FactoryBot.create(:doorkeeper_testing_user)
  end

  subject do
    described_class.new(pre_auth, owner)
  end

  it "creates an access token" do
    expect do
      subject.authorize
    end.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it "returns a code response" do
    expect(subject.authorize).to be_a(Doorkeeper::OAuth::CodeResponse)
  end

  context "when pre_auth is denied" do
    it "does not create token and returns a error response" do
      expect { subject.deny }.not_to(change { Doorkeeper::AccessToken.count })
      expect(subject.deny).to be_a(Doorkeeper::OAuth::ErrorResponse)
    end
  end

  describe "with custom expiration" do
    context "when proper TTL returned" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          custom_access_token_expires_in do |context|
            context.grant_type == Doorkeeper::OAuth::IMPLICIT ? 1234 : nil
          end
        end
      end

      it "should use the custom ttl" do
        subject.authorize
        token = Doorkeeper::AccessToken.first
        expect(token.expires_in).to eq(1234)
      end
    end

    context "when nil TTL returned" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_token_expires_in ->(resource_owner_id = nil) { 654 }
          custom_access_token_expires_in do |_context|
            nil
          end
        end
      end

      it "should fallback to access_token_expires_in" do
        subject.authorize
        token = Doorkeeper::AccessToken.first
        expect(token.expires_in).to eq(654)
      end
    end

    context "when infinite TTL returned" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_token_expires_in 654
          custom_access_token_expires_in do |_context|
            Float::INFINITY
          end
        end
      end

      it "should fallback to access_token_expires_in" do
        subject.authorize
        token = Doorkeeper::AccessToken.first
        expect(token.expires_in).to be_nil
      end
    end
  end

  context "token reuse" do
    it "creates a new token if there are no matching tokens" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it "creates a new token if scopes do not match" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      FactoryBot.create(
        :access_token,
        application_id: pre_auth.client.id,
        resource_owner_id: owner.id,
        resource_owner_type: owner.class.name,
        scopes: "",
      )

      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it "skips token creation if there is a matching one reusable" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      allow(application.scopes).to receive(:has_scopes?).and_return(true)
      allow(application.scopes).to receive(:all?).and_return(true)

      FactoryBot.create(
        :access_token, application_id: pre_auth.client.id,
                       resource_owner_id: owner.id, resource_owner_type: owner.class.name, scopes: "public",
      )

      expect { subject.authorize }.not_to(change { Doorkeeper::AccessToken.count })
    end

    it "creates new token if there is a matching one but non reusable" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      allow(application.scopes).to receive(:has_scopes?).and_return(true)
      allow(application.scopes).to receive(:all?).and_return(true)

      FactoryBot.create(
        :access_token,
        application_id: pre_auth.client.id,
        resource_owner_id: owner.id,
        resource_owner_type: owner.class.name,
        scopes: "public",
      )

      allow_any_instance_of(Doorkeeper::AccessToken).to receive(:reusable?).and_return(false)

      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end
  end
end

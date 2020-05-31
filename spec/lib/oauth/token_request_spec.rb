# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::TokenRequest do
  subject(:request) do
    described_class.new(pre_auth, owner)
  end

  let(:application) do
    FactoryBot.create(:application, scopes: "public")
  end

  let(:pre_auth) do
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

  let(:owner) do
    FactoryBot.create(:doorkeeper_testing_user, name: "John")
  end

  it "creates an access token" do
    expect do
      request.authorize
    end.to change { Doorkeeper::AccessToken.count }.by(1)
  end

  it "returns a code response" do
    expect(request.authorize).to be_a(Doorkeeper::OAuth::CodeResponse)
  end

  context "when pre_auth is denied" do
    it "does not create token and returns a error response" do
      expect { request.deny }.not_to(change { Doorkeeper::AccessToken.count })
      expect(request.deny).to be_a(Doorkeeper::OAuth::ErrorResponse)
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

      it "uses the custom ttl" do
        request.authorize
        token = Doorkeeper::AccessToken.first
        expect(token.expires_in).to eq(1234)
      end
    end

    context "when nil TTL returned" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_token_expires_in 654
          custom_access_token_expires_in do |_context|
            nil
          end
        end
      end

      it "fallbacks to access_token_expires_in" do
        request.authorize
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

      it "fallbacks to access_token_expires_in" do
        request.authorize
        token = Doorkeeper::AccessToken.first
        expect(token.expires_in).to be_nil
      end
    end

    context "when custom_access_token_expires_in uses resource_owner condition" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          custom_access_token_expires_in do |context|
            if context.resource_owner&.name == "John"
              10_000
            else
              500
            end
          end
        end
      end

      it "uses configured values for TTL" do
        request = described_class.new(pre_auth, owner)
        request.authorize
        token = Doorkeeper::AccessToken.last
        expect(token.expires_in).to eq(10_000)

        request = described_class.new(pre_auth, nil)
        request.authorize
        token = Doorkeeper::AccessToken.last
        expect(token.expires_in).to eq(500)
      end
    end
  end

  context "when reuse_access_token enabled" do
    it "creates a new token if there are no matching tokens" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)
      expect do
        request.authorize
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
        request.authorize
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

      expect { request.authorize }.not_to(change { Doorkeeper::AccessToken.count })
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
        request.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end
  end
end

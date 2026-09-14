# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Authorization::Token do
  describe ".build_context" do
    it "uses the application of an object that responds to #application" do
      application = double
      source = double(application: application)

      context = described_class.build_context(source, "grant_type", "scopes", "owner")

      expect(context.client).to eq(application)
    end

    it "uses the client of an object that responds to #client" do
      client = double
      source = double(client: client)

      context = described_class.build_context(source, "grant_type", "scopes", "owner")

      expect(context.client).to eq(client)
    end

    it "uses the object itself otherwise" do
      source = Object.new

      context = described_class.build_context(source, "grant_type", "scopes", "owner")

      expect(context.client).to eq(source)
    end
  end

  describe ".access_token_expires_in" do
    let(:context) { double }

    it "returns nil for a never-expiring custom expiration" do
      configuration = double(
        option_defined?: true,
        custom_access_token_expires_in: ->(_context) { Float::INFINITY },
      )

      expect(described_class.access_token_expires_in(configuration, context)).to be_nil
    end

    it "falls back to access_token_expires_in when the custom expiration is nil" do
      configuration = double(
        option_defined?: true,
        custom_access_token_expires_in: ->(_context) {},
        access_token_expires_in: 7200,
      )

      expect(described_class.access_token_expires_in(configuration, context)).to eq(7200)
    end
  end

  describe "#issue_token!" do
    before do
      default_scopes_exist :public
    end

    it "memoizes the issued token" do
      application = FactoryBot.create(:application)
      resource_owner = FactoryBot.create(:doorkeeper_testing_user)
      pre_auth = double(
        client: application,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
      )
      authorization = described_class.new(pre_auth, resource_owner)

      first_token = nil
      expect { first_token = authorization.issue_token! }
        .to change { Doorkeeper::AccessToken.count }.by(1)
      expect { expect(authorization.issue_token!).to be(first_token) }
        .not_to(change { Doorkeeper::AccessToken.count })
    end

    # RFC 8707: the implicit grant carries the resource indicators the
    # pre-authorization validated straight to the access token, since there is
    # no grant to persist them on first.
    context "with resource indicators" do
      # The example above builds its pre_auth inline; these lets are local to
      # this context and only differ from it by carrying resource_indicators.
      let(:application) { FactoryBot.create(:application) }
      let(:resource_owner) { FactoryBot.create(:doorkeeper_testing_user) }
      let(:pre_auth) do
        double(
          client: application,
          scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
          resource_indicators: ["https://api.example.com/", "https://other.example.com/"],
        )
      end
      let(:authorization) { described_class.new(pre_auth, resource_owner) }

      it "carries them to the access token" do
        token = authorization.issue_token!

        expect(token).to be_persisted
        expect(token.resource).to eq("https://api.example.com/ https://other.example.com/")
      end

      it "raises MissingResourceColumn when the access token table lacks the column" do
        allow(Doorkeeper.config.access_token_model).to receive(:resource_indicators_supported?).and_return(false)

        expect { authorization.issue_token! }
          .to raise_error(Doorkeeper::Errors::MissingResourceColumn, /oauth_access_tokens/)
        expect(Doorkeeper::AccessToken.count).to eq(0)
      end
    end
  end

  describe "#application" do
    it "returns the client when it already is an application record" do
      application = FactoryBot.create(:application)
      pre_auth = double(client: application)

      expect(described_class.new(pre_auth, double).application).to eq(application)
    end

    it "returns nil without a client" do
      pre_auth = double(client: nil)

      expect(described_class.new(pre_auth, double).application).to be_nil
    end
  end
end

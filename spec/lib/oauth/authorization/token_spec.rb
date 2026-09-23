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
    let(:context) { double(client: nil) }

    it "returns nil for a never-expiring custom expiration" do
      configuration = double(
        option_defined?: true,
        public_client_access_token_expires_in: nil,
        custom_access_token_expires_in: ->(_context) { Float::INFINITY },
      )

      expect(described_class.access_token_expires_in(configuration, context)).to be_nil
    end

    it "falls back to access_token_expires_in when the custom expiration is nil" do
      configuration = double(
        option_defined?: true,
        public_client_access_token_expires_in: nil,
        custom_access_token_expires_in: ->(_context) {},
        access_token_expires_in: 7200,
      )

      expect(described_class.access_token_expires_in(configuration, context)).to eq(7200)
    end

    it "uses access_token_expires_in when no custom expiration is configured" do
      configuration = double(option_defined?: false, public_client_access_token_expires_in: nil, access_token_expires_in: 7200)

      expect(described_class.access_token_expires_in(configuration, context)).to eq(7200)
    end

    context "with a block" do
      it "falls back to the block when the custom expiration is nil" do
        configuration = double(
          option_defined?: true,
          public_client_access_token_expires_in: nil,
          custom_access_token_expires_in: ->(_context) {},
        )

        expect(described_class.access_token_expires_in(configuration, context) { 300 }).to eq(300)
      end

      it "falls back to the block when no custom expiration is configured" do
        configuration = double(option_defined?: false, public_client_access_token_expires_in: nil)

        expect(described_class.access_token_expires_in(configuration, context) { 300 }).to eq(300)
      end

      it "prefers the custom expiration over the block" do
        configuration = double(
          option_defined?: true,
          public_client_access_token_expires_in: nil,
          custom_access_token_expires_in: ->(_context) { 60 },
        )

        expect(described_class.access_token_expires_in(configuration, context) { 300 }).to eq(60)
      end

      it "returns nil for a never-expiring custom expiration without calling the block" do
        configuration = double(
          option_defined?: true,
          public_client_access_token_expires_in: nil,
          custom_access_token_expires_in: ->(_context) { Float::INFINITY },
        )

        expect(described_class.access_token_expires_in(configuration, context) { raise "unexpected" }).to be_nil
      end
    end

    context "with public_client_access_token_expires_in configured" do
      let(:public_client) { double(confidential?: false) }
      let(:confidential_client) { double(confidential?: true) }

      def configuration(expiration)
        double(
          option_defined?: true,
          public_client_access_token_expires_in: 600,
          custom_access_token_expires_in: ->(_context) { expiration },
        )
      end

      it "caps the expiration of a public client" do
        context = double(client: public_client)

        expect(described_class.access_token_expires_in(configuration(7200), context)).to eq(600)
      end

      it "keeps a shorter expiration of a public client" do
        context = double(client: public_client)

        expect(described_class.access_token_expires_in(configuration(60), context)).to eq(60)
      end

      it "caps a never-expiring expiration of a public client" do
        context = double(client: public_client)

        expect(described_class.access_token_expires_in(configuration(Float::INFINITY), context)).to eq(600)
      end

      it "caps the fallback of a public client" do
        context = double(client: public_client)

        expect(described_class.access_token_expires_in(configuration(nil), context) { nil }).to eq(600)
        expect(described_class.access_token_expires_in(configuration(nil), context) { 7200 }).to eq(600)
        expect(described_class.access_token_expires_in(configuration(nil), context) { 60 }).to eq(60)
      end

      it "treats a request without a client as a public client" do
        context = double(client: nil)

        expect(described_class.access_token_expires_in(configuration(7200), context)).to eq(600)
      end

      it "does not cap the expiration of a confidential client" do
        context = double(client: confidential_client)

        expect(described_class.access_token_expires_in(configuration(7200), context)).to eq(7200)
        expect(described_class.access_token_expires_in(configuration(Float::INFINITY), context)).to be_nil
      end
    end
  end

  describe ".cap_for_public_client" do
    it "returns the expiration unchanged when no cap is configured" do
      configuration = double(public_client_access_token_expires_in: nil)
      application = double(confidential?: false)

      expect(described_class.cap_for_public_client(configuration, application, 7200)).to eq(7200)
      expect(described_class.cap_for_public_client(configuration, application, nil)).to be_nil
    end

    it "treats an application that does not know whether it is confidential as public" do
      configuration = double(public_client_access_token_expires_in: 600)

      expect(described_class.cap_for_public_client(configuration, Object.new, 7200)).to eq(600)
    end

    # A numeric String (ENV read without #to_i, or a value a custom
    # expiration callable returns) is cast by the ORM on write, so the cap
    # has to compare it as a number too.
    context "with a TTL given as a numeric String" do
      let(:application) { double(confidential?: false) }

      it "compares a String cap with an Integer expiration" do
        configuration = double(public_client_access_token_expires_in: "600")

        expect(described_class.cap_for_public_client(configuration, application, 7200)).to eq("600")
        expect(described_class.cap_for_public_client(configuration, application, 60)).to eq(60)
      end

      it "compares a String expiration with an Integer cap" do
        configuration = double(public_client_access_token_expires_in: 600)

        expect(described_class.cap_for_public_client(configuration, application, "7200")).to eq(600)
      end

      it "compares two Strings as numbers rather than lexicographically" do
        configuration = double(public_client_access_token_expires_in: "900")

        expect(described_class.cap_for_public_client(configuration, application, "86400")).to eq("900")
      end

      it "still caps a Float::INFINITY expiration" do
        configuration = double(public_client_access_token_expires_in: 600)

        expect(described_class.cap_for_public_client(configuration, application, Float::INFINITY)).to eq(600)
      end
    end
  end

  describe ".within_public_client_expires_in?" do
    let(:public_client) { double(confidential?: false) }
    let(:configuration) { double(public_client_access_token_expires_in: 600) }

    def token(expires_in:, expires_in_seconds: expires_in)
      double(expires_in: expires_in, expires_in_seconds: expires_in_seconds)
    end

    it "accepts any token when no cap is configured" do
      configuration = double(public_client_access_token_expires_in: nil)

      expect(described_class.within_public_client_expires_in?(configuration, public_client, token(expires_in: nil)))
        .to be(true)
    end

    it "accepts any token of a confidential client" do
      confidential_client = double(confidential?: true)

      expect(
        described_class.within_public_client_expires_in?(configuration, confidential_client, token(expires_in: nil)),
      ).to be(true)
    end

    it "refuses a never-expiring token" do
      expect(described_class.within_public_client_expires_in?(configuration, public_client, token(expires_in: nil)))
        .to be(false)
    end

    it "refuses a token with more lifetime left than the cap" do
      expect(described_class.within_public_client_expires_in?(configuration, public_client, token(expires_in: 7200)))
        .to be(false)
    end

    it "accepts a token whose remaining lifetime fits under the cap" do
      expect(described_class.within_public_client_expires_in?(configuration, public_client, token(expires_in: 600)))
        .to be(true)
      expect(
        described_class.within_public_client_expires_in?(
          configuration, public_client, token(expires_in: 7200, expires_in_seconds: 300),
        ),
      ).to be(true)
    end

    it "treats a request without a client as a public client" do
      expect(described_class.within_public_client_expires_in?(configuration, nil, token(expires_in: 7200)))
        .to be(false)
    end

    it "compares a String cap as a number" do
      configuration = double(public_client_access_token_expires_in: "600")

      expect(described_class.within_public_client_expires_in?(configuration, public_client, token(expires_in: 7200)))
        .to be(false)
      expect(described_class.within_public_client_expires_in?(configuration, public_client, token(expires_in: 60)))
        .to be(true)
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

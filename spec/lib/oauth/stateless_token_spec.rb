# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Stateless JWT tokens" do
  # Decoder lambda used in authenticate tests, extracted to avoid repetition.
  let(:valid_jwt_decoder) do
    lambda do |raw|
      raise "invalid signature" unless raw.start_with?("valid.")

      {
        "resource_owner_id" => 1,
        "scope" => "read",
        "iat" => Time.now.utc.to_i,
        "exp" => (Time.now.utc + 3600).to_i,
      }
    end
  end

  let(:three_segment_token) { "valid.header.payload" }

  describe Doorkeeper::OAuth::StatelessToken do
    let(:iat) { Time.now.utc.to_i }
    let(:exp) { (Time.now.utc + 3600).to_i }
    let(:claims) do
      {
        "resource_owner_id" => 1,
        "scope" => "read write",
        "client_id" => "app-uid",
        "iat" => iat,
        "exp" => exp,
        "expires_in" => 3600,
      }
    end
    let(:application) { double("Application", id: 99, uid: "app-uid") }
    let(:token) { described_class.new(claims: claims, application: application, raw_token: "raw-jwt") }

    describe "#accessible?" do
      it "returns true when not expired" do
        expect(token.accessible?).to be(true)
      end

      it "returns false when expired" do
        expired_claims = claims.merge("exp" => (Time.now.utc - 1).to_i)
        expired_token = described_class.new(claims: expired_claims)
        expect(expired_token.accessible?).to be(false)
      end
    end

    describe "#expired?" do
      it "returns false when not expired" do
        expect(token.expired?).to be(false)
      end

      it "returns true when expired" do
        expired_claims = claims.merge("exp" => (Time.now.utc - 1).to_i)
        expired_token = described_class.new(claims: expired_claims)
        expect(expired_token.expired?).to be(true)
      end

      it "returns false when no exp claim" do
        no_exp_token = described_class.new(claims: claims.except("exp"))
        expect(no_exp_token.expired?).to be(false)
      end
    end

    describe "#revoked?" do
      it "always returns false" do
        expect(token.revoked?).to be(false)
      end
    end

    describe "#revoke" do
      it "is a no-op" do
        expect { token.revoke }.not_to raise_error
      end
    end

    describe "#revoke_previous_refresh_token!" do
      it "is a no-op" do
        expect { token.revoke_previous_refresh_token! }.not_to raise_error
      end
    end

    describe "#revocable?" do
      it "returns false" do
        expect(token.revocable?).to be(false)
      end
    end

    describe "#acceptable?" do
      it "returns true with matching scopes" do
        expect(token.acceptable?(["read"])).to be(true)
      end

      it "returns true with multiple matching scopes (ANY-of semantics)" do
        expect(token.acceptable?(["read", "write"])).to be(true)
      end

      it "returns false with non-matching scopes" do
        expect(token.acceptable?(["admin"])).to be(false)
      end

      it "returns true when required_scopes is blank" do
        expect(token.acceptable?([])).to be(true)
      end

      it "returns true when required_scopes is nil" do
        expect(token.acceptable?(nil)).to be(true)
      end

      it "returns false when token is expired" do
        expired_claims = claims.merge("exp" => (Time.now.utc - 1).to_i)
        expired_token = described_class.new(claims: expired_claims)
        expect(expired_token.acceptable?(["read"])).to be(false)
      end
    end

    describe "#includes_scope?" do
      it "returns true for matching scope" do
        expect(token.includes_scope?("read")).to be(true)
      end

      it "returns false for non-matching scope" do
        expect(token.includes_scope?("admin")).to be(false)
      end

      it "returns true when required_scopes is empty" do
        expect(token.includes_scope?).to be(true)
      end
    end

    describe "#scopes_string" do
      it "returns scope from claims" do
        expect(token.scopes_string).to eq("read write")
      end
    end

    describe "#scopes" do
      it "returns a Scopes object" do
        expect(token.scopes).to be_a(Doorkeeper::OAuth::Scopes)
        expect(token.scopes.to_s).to eq("read write")
      end
    end

    describe "#resource_owner_id" do
      it "returns resource_owner_id from claims" do
        expect(token.resource_owner_id).to eq(1)
      end

      it "falls back to sub claim" do
        sub_token = described_class.new(
          claims: claims.merge("sub" => 42).except("resource_owner_id"),
        )
        expect(sub_token.resource_owner_id).to eq(42)
      end
    end

    describe "#application_id" do
      it "returns application id" do
        expect(token.application_id).to eq(99)
      end

      it "returns nil when no application" do
        no_app_token = described_class.new(claims: claims)
        expect(no_app_token.application_id).to be_nil
      end
    end

    describe "#token" do
      it "returns the raw token" do
        expect(token.token).to eq("raw-jwt")
      end
    end

    describe "#plaintext_token" do
      it "returns the raw token" do
        expect(token.plaintext_token).to eq("raw-jwt")
      end
    end

    describe "#plaintext_refresh_token" do
      it "returns nil" do
        expect(token.plaintext_refresh_token).to be_nil
      end
    end

    describe "#token_type" do
      it "returns Bearer" do
        expect(token.token_type).to eq("Bearer")
      end
    end

    describe "#expires_at" do
      it "returns expiration time from exp claim" do
        expect(token.expires_at).to eq(Time.at(exp).utc)
      end

      it "returns nil when no exp claim" do
        no_exp_token = described_class.new(claims: claims.except("exp"))
        expect(no_exp_token.expires_at).to be_nil
      end
    end

    describe "#expires_in_seconds" do
      it "returns remaining seconds" do
        expect(token.expires_in_seconds).to be > 0
        expect(token.expires_in_seconds).to be <= 3600
      end

      it "returns 0 when expired" do
        expired_claims = claims.merge("exp" => (Time.now.utc - 1).to_i)
        expired_token = described_class.new(claims: expired_claims)
        expect(expired_token.expires_in_seconds).to eq(0)
      end

      it "returns nil when no exp claim and no expires_in" do
        no_exp_token = described_class.new(claims: { "scope" => "read" })
        expect(no_exp_token.expires_in_seconds).to be_nil
      end
    end

    describe "#as_json" do
      it "returns expected shape" do
        json = token.as_json
        expect(json).to include(
          resource_owner_id: 1,
          application: { uid: "app-uid" },
        )
        expect(json[:scope].to_s).to eq("read write")
        expect(json[:expires_in]).to be_a(Integer)
        expect(json[:created_at]).to eq(iat)
      end

      it "includes resource_owner_type when polymorphic_resource_owner is enabled" do
        allow(Doorkeeper.configuration).to receive(:polymorphic_resource_owner?).and_return(true)
        poly_token = described_class.new(
          claims: claims.merge("resource_owner_type" => "User"),
        )
        json = poly_token.as_json
        expect(json[:resource_owner_type]).to eq("User")
      end
    end

    describe "#custom_attributes" do
      it "returns custom attributes from claims" do
        allow(Doorkeeper.config).to receive(:custom_access_token_attributes).and_return(%i[tenant_id])
        custom_token = described_class.new(claims: claims.merge("tenant_id" => "t1"))
        expect(custom_token.custom_attributes).to eq("tenant_id" => "t1")
      end
    end

    describe "#resource" do
      it "returns aud as space-delimited string" do
        aud_token = described_class.new(
          claims: claims.merge("aud" => "https://api.example.com"),
        )
        expect(aud_token.resource).to eq("https://api.example.com")
      end

      it "joins array aud with space" do
        aud_token = described_class.new(
          claims: claims.merge("aud" => %w[https://a.example.com https://b.example.com]),
        )
        expect(aud_token.resource).to eq("https://a.example.com https://b.example.com")
      end

      it "returns nil when aud is blank" do
        expect(token.resource).to be_nil
      end
    end
  end

  describe Doorkeeper::OAuth::Token do
    describe ".authenticate with stateless_jwt_tokens" do
      let(:request) { double("Request").as_null_object }
      let(:opaque_token) { "opaque-token-value" }

      before do
        decoder = valid_jwt_decoder
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          stateless_jwt_tokens
          jwt_token_decoder decoder
        end
      end

      context "with stateless_jwt_tokens enabled" do
        it "returns a StatelessToken for a valid JWT without querying DB" do
          expect(Doorkeeper::AccessToken).not_to receive(:by_token)
          result = described_class.authenticate(request, ->(_r) { three_segment_token })
          expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
          expect(result.raw_token).to eq(three_segment_token)
        end

        it "returns nil for an invalid JWT (decoder raises)" do
          result = described_class.authenticate(request, ->(_r) { "invalid.header.payload" })
          expect(result).to be_nil
        end

        it "returns nil for a JWT where decoder returns nil" do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            stateless_jwt_tokens
            jwt_token_decoder ->(_raw) { nil }
          end
          result = described_class.authenticate(request, ->(_r) { three_segment_token })
          expect(result).to be_nil
        end

        it "falls through to DB path for opaque (non-JWT) tokens" do
          fake_token = double("AccessToken")
          allow(Doorkeeper::AccessToken).to receive(:by_token).with(opaque_token).and_return(fake_token)
          result = described_class.authenticate(request, ->(_r) { opaque_token })
          expect(result).to eq(fake_token)
        end
      end

      context "with stateless_jwt_tokens disabled" do
        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
          end
        end

        it "uses by_token even for 3-segment tokens" do
          fake_token = double("AccessToken")
          allow(Doorkeeper::AccessToken).to receive(:by_token).with(three_segment_token).and_return(fake_token)
          result = described_class.authenticate(request, ->(_r) { three_segment_token })
          expect(result).to eq(fake_token)
        end
      end
    end
  end

  describe "AccessToken.find_or_create_for with stateless_jwt_tokens" do
    let(:application) { FactoryBot.build_stubbed(:application) }
    let(:resource_owner) { FactoryBot.build_stubbed(:resource_owner) }
    let(:scopes) { "read write" }

    before do
      # Define a fake generator class for testing
      stub_const(
        "FakeJwtGenerator",
        Class.new do
          def self.generate(options)
            "fake-jwt-#{options[:resource_owner_id]}-#{options[:created_at].to_i}"
          end
        end,
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        access_token_generator "FakeJwtGenerator"
        jwt_token_decoder ->(_raw) { {} }
      end
    end

    it "returns a StatelessToken without persisting" do
      expect(Doorkeeper::AccessToken).not_to receive(:create!)
      result = Doorkeeper::AccessToken.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: scopes,
      )
      expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
      expect(result.plaintext_token).to start_with("fake-jwt-")
      expect(result.claims["scope"]).to eq("read write")
      expect(result.application).to eq(application)
    end
  end

  describe "Config validations for stateless_jwt_tokens" do
    it "warns when jwt_token_decoder is nil" do
      allow(Rails.logger).to receive(:warn)
      expect(Rails.logger).to receive(:warn).with(
        "[DOORKEEPER] stateless_jwt_tokens is enabled but jwt_token_decoder is not configured. JWT tokens will fail to verify.",
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
      end
    end
  end
end

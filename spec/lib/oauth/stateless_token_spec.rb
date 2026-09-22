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

      it "returns true when no exp claim (non-expiring token)" do
        no_exp_token = described_class.new(claims: claims.except("exp"))
        expect(no_exp_token.accessible?).to be(true)
      end

      it "returns true when exp claim is nil" do
        nil_exp_token = described_class.new(claims: claims.merge("exp" => nil))
        expect(nil_exp_token.accessible?).to be(true)
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

      it "returns false when token is expired even if required_scopes is blank" do
        expired_claims = claims.merge("exp" => (Time.now.utc - 1).to_i)
        expired_token = described_class.new(claims: expired_claims)
        expect(expired_token.acceptable?([])).to be(false)
      end

      it "returns true with matching scopes when no exp claim" do
        no_exp_token = described_class.new(claims: claims.except("exp"))
        expect(no_exp_token.acceptable?(["read"])).to be(true)
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

      it "returns true when any of the required scopes matches" do
        expect(token.includes_scope?("admin", "write")).to be(true)
      end

      it "accepts symbols" do
        expect(token.includes_scope?(:read)).to be(true)
      end

      [nil, ""].each do |blank_scope|
        context "when scope claim is #{blank_scope.inspect}" do
          let(:blank_scope_token) { described_class.new(claims: claims.merge("scope" => blank_scope)) }

          it "returns false for any required scope" do
            expect(blank_scope_token.includes_scope?("read")).to be(false)
          end

          it "returns true when required_scopes is empty" do
            expect(blank_scope_token.includes_scope?).to be(true)
          end
        end
      end

      context "when scope claim is missing" do
        let(:no_scope_token) { described_class.new(claims: claims.except("scope")) }

        it "returns false for any required scope" do
          expect(no_scope_token.includes_scope?("read")).to be(false)
        end

        it "returns true when required_scopes is empty" do
          expect(no_scope_token.includes_scope?).to be(true)
        end
      end
    end

    describe "#scopes_string" do
      it "returns scope from claims" do
        expect(token.scopes_string).to eq("read write")
      end

      it "returns an empty string when scope claim is nil" do
        nil_scope_token = described_class.new(claims: claims.merge("scope" => nil))
        expect(nil_scope_token.scopes_string).to eq("")
      end
    end

    describe "#scopes" do
      it "returns a Scopes object" do
        expect(token.scopes).to be_a(Doorkeeper::OAuth::Scopes)
        expect(token.scopes.to_s).to eq("read write")
      end

      it "returns empty Scopes when scope claim is nil" do
        nil_scope_token = described_class.new(claims: claims.merge("scope" => nil))
        expect(nil_scope_token.scopes).to be_a(Doorkeeper::OAuth::Scopes)
        expect(nil_scope_token.scopes.all).to be_empty
      end

      it "returns empty Scopes when scope claim is an empty string" do
        empty_scope_token = described_class.new(claims: claims.merge("scope" => ""))
        expect(empty_scope_token.scopes.all).to be_empty
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

    describe "#expires_in" do
      it "returns expires_in from claims" do
        expect(token.expires_in).to eq(3600)
      end

      it "returns nil when no expires_in claim" do
        no_expires_in_token = described_class.new(claims: claims.except("expires_in"))
        expect(no_expires_in_token.expires_in).to be_nil
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

      it "does not include resource_owner_type when polymorphic_resource_owner is disabled" do
        poly_token = described_class.new(
          claims: claims.merge("resource_owner_type" => "User"),
        )
        expect(poly_token.as_json).not_to have_key(:resource_owner_type)
      end

      it "returns nil application uid when no application" do
        no_app_token = described_class.new(claims: claims)
        expect(no_app_token.as_json[:application]).to eq(uid: nil)
      end

      it "returns nil expires_in when no exp claim" do
        no_exp_token = described_class.new(claims: claims.except("exp"))
        expect(no_exp_token.as_json[:expires_in]).to be_nil
      end
    end

    describe "#custom_attributes" do
      it "returns custom attributes from claims" do
        allow(Doorkeeper.config).to receive(:custom_access_token_attributes).and_return(%i[tenant_id])
        custom_token = described_class.new(claims: claims.merge("tenant_id" => "t1"))
        expect(custom_token.custom_attributes).to eq("tenant_id" => "t1")
      end

      it "ignores claims that are not configured as custom attributes" do
        custom_token = described_class.new(claims: claims.merge("tenant_id" => "t1"))
        expect(custom_token.custom_attributes).to eq({})
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

      it "returns the single value for a one-element array aud" do
        aud_token = described_class.new(claims: claims.merge("aud" => %w[https://a.example.com]))
        expect(aud_token.resource).to eq("https://a.example.com")
      end

      [nil, "", []].each do |blank_aud|
        it "returns nil when aud is #{blank_aud.inspect}" do
          aud_token = described_class.new(claims: claims.merge("aud" => blank_aud))
          expect(aud_token.resource).to be_nil
        end
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

        it "exposes the decoded claims on the returned token" do
          result = described_class.authenticate(request, ->(_r) { three_segment_token })
          expect(result.claims).to include("resource_owner_id" => 1, "scope" => "read")
          expect(result.token).to eq(three_segment_token)
          expect(result).to be_accessible
        end

        it "does not fall back to DB lookup when the decoder raises" do
          expect(Doorkeeper::AccessToken).not_to receive(:by_token)
          result = described_class.authenticate(request, ->(_r) { "invalid.header.payload" })
          expect(result).to be_nil
        end

        it "returns nil when no credentials are found without invoking the decoder" do
          decoder = double("decoder")
          config_is_set(:jwt_token_decoder, decoder)

          expect(decoder).not_to receive(:call)
          expect(Doorkeeper::AccessToken).not_to receive(:by_token)
          result = described_class.authenticate(request, ->(_r) {})
          expect(result).to be_nil
        end

        it "finds a persisted opaque token in the database without invoking the decoder" do
          decoder = double("decoder")
          config_is_set(:jwt_token_decoder, decoder)
          access_token = FactoryBot.create(:access_token)

          expect(decoder).not_to receive(:call)
          result = described_class.authenticate(request, ->(_r) { access_token.token })
          expect(result).to eq(access_token)
        end

        it "returns nil for an unknown opaque token" do
          result = described_class.authenticate(request, ->(_r) { opaque_token })
          expect(result).to be_nil
        end

        %w[header.payload header.payload.signature.extra].each do |not_a_jwt|
          it "falls through to DB path for a #{not_a_jwt.split(".").length}-segment token" do
            fake_token = double("AccessToken")
            allow(Doorkeeper::AccessToken).to receive(:by_token).with(not_a_jwt).and_return(fake_token)
            result = described_class.authenticate(request, ->(_r) { not_a_jwt })
            expect(result).to eq(fake_token)
          end
        end

        context "when jwt_token_decoder is not configured" do
          before do
            allow(Rails.logger).to receive(:warn)
            Doorkeeper.configure do
              orm DOORKEEPER_ORM
              stateless_jwt_tokens
            end
          end

          it "returns nil for a JWT without querying DB" do
            expect(Doorkeeper::AccessToken).not_to receive(:by_token)
            result = described_class.authenticate(request, ->(_r) { three_segment_token })
            expect(result).to be_nil
          end
        end

        ["a string", %w[an array], 42, true].each do |not_a_hash|
          it "returns nil when the decoder returns #{not_a_hash.class}" do
            config_is_set(:jwt_token_decoder, ->(_raw) { not_a_hash })

            expect(Doorkeeper::AccessToken).not_to receive(:by_token)
            result = described_class.authenticate(request, ->(_r) { three_segment_token })
            expect(result).to be_nil
          end
        end

        context "when the decoder returns claims of an expired JWT" do
          before do
            config_is_set(
              :jwt_token_decoder,
              ->(_raw) { { "scope" => "read", "iat" => 2.hours.ago.to_i, "exp" => 1.hour.ago.to_i } },
            )
          end

          it "returns a StatelessToken that is not accessible" do
            result = described_class.authenticate(request, ->(_r) { three_segment_token })
            expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
            expect(result).to be_expired
            expect(result).not_to be_accessible
            expect(result.acceptable?(["read"])).to be(false)
          end
        end

        context "when the decoder returns claims without exp" do
          before do
            config_is_set(:jwt_token_decoder, ->(_raw) { { "scope" => "read", "iat" => Time.now.utc.to_i } })
          end

          it "returns a non-expiring StatelessToken" do
            result = described_class.authenticate(request, ->(_r) { three_segment_token })
            expect(result.expires_at).to be_nil
            expect(result).not_to be_expired
            expect(result).to be_accessible
            expect(result.acceptable?(["read"])).to be(true)
          end
        end

        describe "application resolving" do
          let(:decoded_claims) { { "scope" => "read", "client_id" => client_id } }

          before do
            claims = decoded_claims
            config_is_set(:jwt_token_decoder, ->(_raw) { claims })
          end

          context "when client_id claim matches an application" do
            let(:application) { FactoryBot.create(:application) }
            let(:client_id) { application.uid }

            it "resolves the application by uid" do
              result = described_class.authenticate(request, ->(_r) { three_segment_token })
              expect(result.application).to eq(application)
              expect(result.application_id).to eq(application.id)
            end
          end

          context "when client_id claim does not match any application" do
            let(:client_id) { "unknown-uid" }

            it "returns a token without application" do
              result = described_class.authenticate(request, ->(_r) { three_segment_token })
              expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
              expect(result.application).to be_nil
              expect(result.application_id).to be_nil
            end
          end

          [nil, "", " "].each do |blank_client_id|
            context "when client_id claim is #{blank_client_id.inspect}" do
              let(:client_id) { blank_client_id }

              it "returns a token without application and does not query applications" do
                expect(Doorkeeper::Application).not_to receive(:find_by)
                result = described_class.authenticate(request, ->(_r) { three_segment_token })
                expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
                expect(result.application).to be_nil
              end
            end
          end

          context "when client_id claim is missing" do
            let(:decoded_claims) { { "scope" => "read" } }

            it "returns a token without application and does not query applications" do
              expect(Doorkeeper::Application).not_to receive(:find_by)
              result = described_class.authenticate(request, ->(_r) { three_segment_token })
              expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
              expect(result.application).to be_nil
            end
          end

          context "when the application lookup raises" do
            let(:client_id) { "app-uid" }

            before do
              allow(Doorkeeper::Application).to receive(:find_by)
                .with(uid: client_id).and_raise(StandardError, "database is down")
            end

            it "returns a token without application" do
              result = described_class.authenticate(request, ->(_r) { three_segment_token })
              expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
              expect(result.claims).to eq(decoded_claims)
              expect(result.application).to be_nil
            end
          end
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

        it "does not invoke the decoder even if it is configured" do
          decoder = double("decoder")
          config_is_set(:jwt_token_decoder, decoder)

          expect(decoder).not_to receive(:call)
          result = described_class.authenticate(request, ->(_r) { three_segment_token })
          expect(result).to be_nil
        end

        it "finds a persisted JWT-shaped token in the database" do
          stub_const(
            "ThreeSegmentGenerator",
            Class.new do
              def self.generate(_options = {})
                "valid.header.payload"
              end
            end,
          )
          config_is_set(:access_token_generator, "ThreeSegmentGenerator")
          access_token = FactoryBot.create(:access_token)

          result = described_class.authenticate(request, ->(_r) { three_segment_token })
          expect(result).to eq(access_token)
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

    it "does not create an access token record" do
      expect do
        Doorkeeper::AccessToken.find_or_create_for(
          application: application,
          resource_owner: resource_owner,
          scopes: scopes,
        )
      end.not_to(change { Doorkeeper::AccessToken.count })
    end

    it "accepts scopes as a Scopes object" do
      result = Doorkeeper::AccessToken.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string(scopes),
      )
      expect(result.claims["scope"]).to eq("read write")
      expect(result.scopes.all).to eq(%w[read write])
    end

    it "passes token attributes to the configured generator" do
      expect(FakeJwtGenerator).to receive(:generate).with(
        hash_including(
          resource_owner_id: resource_owner.id,
          application: application,
          expires_in: 600,
          created_at: kind_of(Time),
        ),
      ).and_call_original

      result = Doorkeeper::AccessToken.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: scopes,
        expires_in: 600,
      )
      expect(result.token).to eq("fake-jwt-#{resource_owner.id}-#{result.claims["iat"]}")
    end

    describe "claims" do
      subject(:claims) do
        Doorkeeper::AccessToken.find_or_create_for(
          application: application,
          resource_owner: resource_owner,
          scopes: scopes,
          **token_attributes,
        ).claims
      end

      let(:token_attributes) { {} }

      it "includes resource owner, scope and client" do
        expect(claims).to include(
          "resource_owner_id" => resource_owner.id,
          "scope" => "read write",
          "client_id" => application.uid,
        )
      end

      it "sets iat to the current time" do
        expect(claims["iat"]).to be_within(5).of(Time.now.utc.to_i)
      end

      it "sets exp and expires_in from access_token_expires_in by default" do
        expect(claims["expires_in"]).to eq(Doorkeeper.config.access_token_expires_in)
        expect(claims["exp"]).to eq(claims["iat"] + Doorkeeper.config.access_token_expires_in)
      end

      it "does not include resource_owner_type" do
        expect(claims).not_to have_key("resource_owner_type")
      end

      context "when resource owner is passed as an id" do
        let(:resource_owner) { 42 }

        it "uses it as resource_owner_id" do
          expect(claims["resource_owner_id"]).to eq(42)
        end
      end

      context "without application" do
        let(:application) { nil }

        it "sets client_id to nil" do
          expect(claims).to include("client_id" => nil)
        end
      end

      context "with custom expires_in" do
        let(:token_attributes) { { expires_in: 600 } }

        it "prefers it over access_token_expires_in" do
          expect(claims["expires_in"]).to eq(600)
          expect(claims["exp"]).to eq(claims["iat"] + 600)
        end
      end

      context "when access tokens do not expire" do
        before { config_is_set(:access_token_expires_in, nil) }

        it "omits the exp claim" do
          expect(claims).not_to have_key("exp")
          expect(claims["expires_in"]).to be_nil
        end

        it "builds a non-expiring token" do
          token = Doorkeeper::AccessToken.find_or_create_for(
            application: application,
            resource_owner: resource_owner,
            scopes: scopes,
          )
          expect(token.expires_at).to be_nil
          expect(token.expires_in_seconds).to be_nil
          expect(token).to be_accessible
        end
      end

      context "with polymorphic resource owner" do
        before { config_is_set(:polymorphic_resource_owner, true) }

        it "includes resource_owner_type" do
          expect(claims).to include(
            "resource_owner_id" => resource_owner.id,
            "resource_owner_type" => resource_owner.class.name,
          )
        end
      end

      context "with custom_access_token_attributes" do
        before { config_is_set(:custom_access_token_attributes, [:tenant_name]) }

        let(:token_attributes) { { tenant_name: "Tenant 1", not_configured: "value" } }

        it "includes configured custom attributes" do
          expect(claims).to include("tenant_name" => "Tenant 1")
        end

        it "ignores attributes that are not configured" do
          expect(claims).not_to have_key("not_configured")
        end

        it "exposes them via StatelessToken#custom_attributes" do
          token = Doorkeeper::AccessToken.find_or_create_for(
            application: application,
            resource_owner: resource_owner,
            scopes: scopes,
            **token_attributes,
          )
          expect(token.custom_attributes).to eq("tenant_name" => "Tenant 1")
        end

        context "when the attribute is not passed" do
          let(:token_attributes) { {} }

          it "omits the claim" do
            expect(claims).not_to have_key("tenant_name")
          end
        end
      end
    end

    context "with reuse_access_token enabled" do
      before { config_is_set(:reuse_access_token, true) }

      it "does not look for a matching token" do
        expect(Doorkeeper::AccessToken).not_to receive(:matching_token_for)
        result = Doorkeeper::AccessToken.find_or_create_for(
          application: application,
          resource_owner: resource_owner,
          scopes: scopes,
        )
        expect(result).to be_a(Doorkeeper::OAuth::StatelessToken)
      end
    end

    context "when the generator does not respond to .generate" do
      before do
        stub_const("NoGenerateJwtGenerator", Module.new)
        config_is_set(:access_token_generator, "NoGenerateJwtGenerator")
      end

      it "raises UnableToGenerateToken" do
        expect do
          Doorkeeper::AccessToken.find_or_create_for(
            application: application,
            resource_owner: resource_owner,
            scopes: scopes,
          )
        end.to raise_error(Doorkeeper::Errors::UnableToGenerateToken)
      end
    end

    context "when the generator cannot be found" do
      before { config_is_set(:access_token_generator, "NotExistingJwtGenerator") }

      it "raises TokenGeneratorNotFound" do
        expect do
          Doorkeeper::AccessToken.find_or_create_for(
            application: application,
            resource_owner: resource_owner,
            scopes: scopes,
          )
        end.to raise_error(Doorkeeper::Errors::TokenGeneratorNotFound, /NotExistingJwtGenerator/)
      end
    end
  end

  describe "AccessToken.find_or_create_for without stateless_jwt_tokens" do
    let(:application) { FactoryBot.create(:application) }
    let(:resource_owner) { FactoryBot.create(:resource_owner) }

    it "persists a regular access token" do
      result = nil
      expect do
        result = Doorkeeper::AccessToken.find_or_create_for(
          application: application,
          resource_owner: resource_owner,
          scopes: "public",
        )
      end.to change { Doorkeeper::AccessToken.count }.by(1)
      expect(result).to be_a(Doorkeeper::AccessToken)
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

    it "warns when access_token_generator is the default opaque generator" do
      expect(Rails.logger).to receive(:warn).with(
        /stateless_jwt_tokens is enabled but access_token_generator is the default opaque generator/,
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        jwt_token_decoder ->(_raw) { {} }
      end
    end

    it "warns when refresh tokens are enabled" do
      expect(Rails.logger).to receive(:warn).with(
        /stateless_jwt_tokens is enabled but refresh tokens are also enabled/,
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        access_token_generator "FakeJwtGenerator"
        jwt_token_decoder ->(_raw) { {} }
        use_refresh_token
      end
    end

    it "warns when refresh tokens are enabled with a block" do
      expect(Rails.logger).to receive(:warn).with(
        /stateless_jwt_tokens is enabled but refresh tokens are also enabled/,
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        access_token_generator "FakeJwtGenerator"
        jwt_token_decoder ->(_raw) { {} }
        use_refresh_token { |_context| false }
      end
    end

    it "warns when reuse_access_token is enabled" do
      expect(Rails.logger).to receive(:warn).with(
        /stateless_jwt_tokens is enabled but reuse_access_token is also enabled/,
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        access_token_generator "FakeJwtGenerator"
        jwt_token_decoder ->(_raw) { {} }
        reuse_access_token
      end
    end

    it "emits every applicable warning" do
      expect(Rails.logger).to receive(:warn).with(/jwt_token_decoder is not configured/)
      expect(Rails.logger).to receive(:warn).with(/access_token_generator is the default opaque generator/)
      expect(Rails.logger).to receive(:warn).with(/refresh tokens are also enabled/)
      expect(Rails.logger).to receive(:warn).with(/reuse_access_token is also enabled/)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        use_refresh_token
        reuse_access_token
      end
    end

    it "does not warn when everything is configured properly" do
      expect(Rails.logger).not_to receive(:warn)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
        access_token_generator "FakeJwtGenerator"
        jwt_token_decoder ->(_raw) { {} }
      end
    end

    it "does not warn when stateless_jwt_tokens is disabled" do
      expect(Rails.logger).not_to receive(:warn)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
        reuse_access_token
      end
    end
  end

  describe "Config options for stateless_jwt_tokens" do
    it "is disabled by default" do
      expect(Doorkeeper.config.stateless_jwt_tokens?).to be(false)
    end

    it "has no jwt_token_decoder by default" do
      expect(Doorkeeper.config.jwt_token_decoder).to be_nil
    end

    it "can be enabled" do
      allow(Rails.logger).to receive(:warn)
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        stateless_jwt_tokens
      end

      expect(Doorkeeper.config.stateless_jwt_tokens?).to be(true)
    end

    it "stores the configured jwt_token_decoder" do
      decoder = ->(_raw) { {} }
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        jwt_token_decoder decoder
      end

      expect(Doorkeeper.config.jwt_token_decoder).to eq(decoder)
    end
  end
end

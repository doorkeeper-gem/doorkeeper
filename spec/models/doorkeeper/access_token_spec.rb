# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::AccessToken do
  subject { FactoryBot.build(:access_token) }

  it { expect(subject).to be_valid }

  it_behaves_like "an accessible token"
  it_behaves_like "a revocable token"
  it_behaves_like "a unique token" do
    let(:factory_name) { :access_token }
  end

  module CustomGeneratorArgs
    def self.generate; end
  end

  describe "#generate_token" do
    it "generates a token using the default method" do
      FactoryBot.create :access_token

      token = FactoryBot.create :access_token
      expect(token.token).to be_a(String)
    end

    context "with hashing enabled" do
      let(:token) { FactoryBot.create :access_token }

      include_context "with token hashing enabled"

      it "holds a volatile plaintext token when created" do
        expect(token.plaintext_token).to be_a(String)
        expect(token.token)
          .to eq(hashed_or_plain_token_func.call(token.plaintext_token))

        # Finder method only finds the hashed token
        loaded = described_class.find_by(token: token.token)
        expect(loaded).to eq(token)
        expect(loaded.plaintext_token).to be_nil
        expect(loaded.token).to eq(token.token)
      end

      it "does not find_by plain text tokens" do
        expect(described_class.find_by(token: token.plaintext_token)).to be_nil
      end

      describe "with having a plain text token" do
        let(:plain_text_token) { "plain text token" }
        let(:access_token) { FactoryBot.create :access_token }

        before do
          # Assume we have a plain text token from before activating the option
          access_token.update_column(:token, plain_text_token)
        end

        context "without fallback lookup" do
          it "does not provide lookups with either through by_token" do
            expect(described_class.by_token(plain_text_token)).to eq(nil)
            expect(described_class.by_token(access_token.token)).to eq(nil)

            # And it does not touch the token
            access_token.reload
            expect(access_token.token).to eq(plain_text_token)
          end
        end

        context "with fallback lookup" do
          include_context "with token hashing and fallback lookup enabled"

          it "upgrades a plain token when falling back to it" do
            # Side-effect: This will automatically upgrade the token
            expect(described_class).to receive(:upgrade_fallback_value).and_call_original
            expect(described_class.by_token(plain_text_token))
              .to have_attributes(
                resource_owner_id: access_token.resource_owner_id,
                application_id: access_token.application_id,
                scopes: access_token.scopes,
              )

            # Will find subsequently by hashing the token
            expect(described_class.by_token(plain_text_token))
              .to have_attributes(
                resource_owner_id: access_token.resource_owner_id,
                application_id: access_token.application_id,
                scopes: access_token.scopes,
              )

            # Not all the ORM support :id PK
            if access_token.respond_to?(:id)
              expect(described_class.by_token(plain_text_token).id).to eq(access_token.id)
            end

            # And it modifies the token value
            access_token.reload
            expect(access_token.token).not_to eq(plain_text_token)
            expect(described_class.find_by(token: plain_text_token)).to eq(nil)
            expect(described_class.find_by(token: access_token.token)).not_to be_nil
          end
        end
      end
    end

    it "generates a token using a custom object" do
      eigenclass = class << CustomGeneratorArgs; self; end
      eigenclass.class_eval do
        remove_method :generate
      end
      module CustomGeneratorArgs
        def self.generate(opts = {})
          id = opts[:resource_owner_id] || opts[:resource_owner]&.id
          "custom_generator_token_#{id}"
        end
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "CustomGeneratorArgs"
      end

      owner = FactoryBot.create :resource_owner
      token = FactoryBot.create :access_token,
                                resource_owner_id: owner.id,
                                resource_owner_type: owner.class.name

      expect(token.token).to match(/custom_generator_token_\d+/)
    end

    it "allows the custom generator to access the application details" do
      eigenclass = class << CustomGeneratorArgs; self; end
      eigenclass.class_eval do
        remove_method :generate
      end

      module CustomGeneratorArgs
        def self.generate(opts = {})
          "custom_generator_token_#{opts[:application].name}"
        end
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "CustomGeneratorArgs"
      end

      token = FactoryBot.create :access_token
      expect(token.token).to match(/custom_generator_token_Application \d+/)
    end

    it "allows the custom generator to access the scopes" do
      eigenclass = class << CustomGeneratorArgs; self; end
      eigenclass.class_eval do
        remove_method :generate
      end
      module CustomGeneratorArgs
        def self.generate(opts = {})
          "custom_generator_token_#{opts[:scopes].count}_#{opts[:scopes]}"
        end
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "CustomGeneratorArgs"
      end

      token = FactoryBot.create :access_token, scopes: "public write"

      expect(token.token).to eq "custom_generator_token_2_public write"
    end

    it "allows the custom generator to access the expiry length" do
      eigenclass = class << CustomGeneratorArgs; self; end
      eigenclass.class_eval do
        remove_method :generate
      end
      module CustomGeneratorArgs
        def self.generate(opts = {})
          "custom_generator_token_#{opts[:expires_in]}"
        end
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "CustomGeneratorArgs"
      end

      token = FactoryBot.create :access_token
      expect(token.token).to eq "custom_generator_token_7200"
    end

    it "allows the custom generator to access the created time" do
      module CustomGeneratorArgs
        def self.generate(opts = {})
          "custom_generator_token_#{opts[:created_at].to_i}"
        end
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "CustomGeneratorArgs"
      end

      token = FactoryBot.create :access_token
      created_at = token.created_at
      expect(token.token).to eq "custom_generator_token_#{created_at.to_i}"
    end

    it "raises an error if the custom object does not support generate" do
      module NoGenerate
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "NoGenerate"
      end

      expect { FactoryBot.create :access_token }.to(
        raise_error(Doorkeeper::Errors::UnableToGenerateToken),
      )
    end

    it "raises original error if something went wrong in custom generator" do
      eigenclass = class << CustomGeneratorArgs; self; end
      eigenclass.class_eval do
        remove_method :generate
      end

      module CustomGeneratorArgs
        def self.generate(_opts = {})
          raise LoadError, "custom behaviour"
        end
      end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "CustomGeneratorArgs"
      end

      expect { FactoryBot.create :access_token }.to(
        raise_error(LoadError),
      )
    end

    it "raises an error if the custom object does not exist" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "Doorkeeper::NotReal"
      end

      expect { FactoryBot.create :access_token }.to(
        raise_error(Doorkeeper::Errors::TokenGeneratorNotFound, /NotReal/),
      )
    end
  end

  describe "refresh_token" do
    it "has empty refresh token if it was not required" do
      token = FactoryBot.create :access_token
      expect(token.refresh_token).to be_nil
    end

    it "generates a refresh token if it was requested" do
      token = FactoryBot.create :access_token, use_refresh_token: true
      expect(token.refresh_token).not_to be_nil
    end

    it "is not valid if token exists" do
      token1 = FactoryBot.create :access_token, use_refresh_token: true
      token2 = FactoryBot.create :access_token, use_refresh_token: true
      token2.refresh_token = token1.refresh_token
      expect(token2).not_to be_valid
    end

    it "expects database to raise an error if refresh tokens are the same" do
      token1 = FactoryBot.create :access_token, use_refresh_token: true
      token2 = FactoryBot.create :access_token, use_refresh_token: true
      expect do
        token2.refresh_token = token1.refresh_token
        token2.save(validate: false)
      end.to raise_error(uniqueness_error)
    end

    context "with hashing enabled" do
      include_context "with token hashing enabled"
      let(:token) { FactoryBot.create :access_token, use_refresh_token: true }

      it "holds a volatile refresh token when created" do
        expect(token.plaintext_refresh_token).to be_a(String)
        expect(token.refresh_token)
          .to eq(hashed_or_plain_token_func.call(token.plaintext_refresh_token))

        # Finder method only finds the hashed token
        loaded = described_class.find_by(refresh_token: token.refresh_token)
        expect(loaded).to eq(token)
        expect(loaded.plaintext_refresh_token).to be_nil
        expect(loaded.refresh_token).to eq(token.refresh_token)
      end

      it "does not find_by plain text refresh tokens" do
        expect(described_class.find_by(refresh_token: token.plaintext_refresh_token)).to be_nil
      end

      describe "with having a plain text token" do
        let(:plain_refresh_token) { "plain refresh token" }
        let(:access_token) { FactoryBot.create :access_token }

        before do
          # Assume we have a plain text token from before activating the option
          access_token.update_column(:refresh_token, plain_refresh_token)
        end

        context "without fallback lookup" do
          it "does not provide lookups with either through by_token" do
            expect(described_class.by_refresh_token(plain_refresh_token)).to eq(nil)
            expect(described_class.by_refresh_token(access_token.refresh_token)).to eq(nil)

            # And it does not touch the token
            access_token.reload
            expect(access_token.refresh_token).to eq(plain_refresh_token)
          end
        end

        context "with fallback lookup" do
          include_context "with token hashing and fallback lookup enabled"

          it "upgrades a plain token when falling back to it" do
            # Side-effect: This will automatically upgrade the token
            expect(described_class).to receive(:upgrade_fallback_value).and_call_original
            expect(described_class.by_refresh_token(plain_refresh_token))
              .to have_attributes(
                token: access_token.token,
                resource_owner_id: access_token.resource_owner_id,
                application_id: access_token.application_id,
              )

            # Will find subsequently by hashing the token
            expect(described_class.by_refresh_token(plain_refresh_token))
              .to have_attributes(
                token: access_token.token,
                resource_owner_id: access_token.resource_owner_id,
                application_id: access_token.application_id,
              )

            # Not all the ORM support :id PK
            if access_token.respond_to?(:id)
              expect(described_class.by_refresh_token(plain_refresh_token).id).to eq(access_token.id)
            end

            # And it modifies the token value
            access_token.reload
            expect(access_token.refresh_token).not_to eq(plain_refresh_token)
            expect(described_class.find_by(refresh_token: plain_refresh_token)).to eq(nil)
            expect(described_class.find_by(refresh_token: access_token.refresh_token)).not_to be_nil
          end
        end
      end
    end
  end

  describe "validations" do
    it "is valid without resource_owner_id" do
      # For client credentials flow
      subject.resource_owner_id = nil
      expect(subject).to be_valid
    end

    it "is valid without application_id" do
      # For resource owner credentials flow
      subject.application_id = nil
      expect(subject).to be_valid
    end
  end

  describe "#same_credential?" do
    context "with default parameters" do
      let(:resource_owner) { FactoryBot.create(:resource_owner) }
      let(:resource_owner_id) { resource_owner.id }
      let(:application) { FactoryBot.create :application }
      let(:default_attributes) do
        {
          application: application,
          resource_owner_id: resource_owner_id,
          resource_owner_type: resource_owner.class.name,
        }
      end
      let(:access_token1) { FactoryBot.create :access_token, default_attributes }

      context "when the second token has the same owner and same app" do
        let(:access_token2) { FactoryBot.create :access_token, default_attributes }

        it "success" do
          expect(access_token1).to be_same_credential(access_token2)
        end
      end

      context "when the second token has same owner and different app" do
        let(:other_application) { FactoryBot.create :application }
        let(:access_token2) do
          FactoryBot.create :access_token,
                            application: other_application,
                            resource_owner_id: resource_owner_id,
                            resource_owner_type: resource_owner.class.name
        end

        it "fails" do
          expect(access_token1).not_to be_same_credential(access_token2)
        end
      end

      context "when the second token has different owner and different app" do
        let(:other_application) { FactoryBot.create :application }
        let(:access_token2) do
          FactoryBot.create :access_token,
                            application: other_application,
                            resource_owner_id: resource_owner.id + 1
        end

        it "fails" do
          expect(access_token1).not_to be_same_credential(access_token2)
        end
      end

      context "when the second token has different owner and same app" do
        let(:access_token2) do
          FactoryBot.create :access_token,
                            application: application,
                            resource_owner_id: resource_owner.id + 1
        end

        it "fails" do
          expect(access_token1).not_to be_same_credential(access_token2)
        end
      end
    end
  end

  describe "#acceptable?" do
    context "when token is not accessible" do
      let(:token) { FactoryBot.create(:access_token, created_at: 6.hours.ago) }

      it "returns false" do
        expect(token.acceptable?(nil)).to be false
      end
    end

    context "when token has the incorrect scopes" do
      let(:token) { FactoryBot.create(:access_token) }

      it "returns false" do
        expect(token.acceptable?(["public"])).to be false
      end
    end

    context "when token is acceptable with the correct scopes" do
      let(:token) do
        token = FactoryBot.create(:access_token)
        token[:scopes] = "public"
        token
      end

      it "returns true" do
        expect(token.acceptable?(["public"])).to be true
      end
    end
  end

  describe ".revoke_all_for" do
    let(:resource_owner) { FactoryBot.create :resource_owner }
    let(:application)    { FactoryBot.create :application }
    let(:default_attributes) do
      {
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      }
    end

    it "revokes all tokens for given application and resource owner" do
      FactoryBot.create :access_token, default_attributes
      described_class.revoke_all_for application.id, resource_owner
      expect(described_class.all).to all(be_revoked)
    end

    it "matches application" do
      access_token_for_different_app = FactoryBot.create(
        :access_token,
        default_attributes.merge(application: FactoryBot.create(:application)),
      )

      described_class.revoke_all_for application.id, resource_owner

      expect(access_token_for_different_app.reload).not_to be_revoked
    end

    it "matches resource owner" do
      access_token_for_different_owner = FactoryBot.create(
        :access_token,
        default_attributes.merge(resource_owner_id: resource_owner.id + 1),
      )

      described_class.revoke_all_for application.id, resource_owner

      expect(access_token_for_different_owner.reload).not_to be_revoked
    end
  end

  describe ".matching_token_for" do
    let(:resource_owner)    { FactoryBot.create :resource_owner }
    let(:resource_owner_id) { resource_owner.id }
    let(:application)       { FactoryBot.create :application }
    let(:scopes) { Doorkeeper::OAuth::Scopes.from_string("public write") }
    let(:default_attributes) do
      {
        application: application,
        resource_owner_id: resource_owner_id,
        resource_owner_type: resource_owner.class.name,
        scopes: scopes.to_s,
      }
    end

    before do
      default_scopes_exist(*scopes.all)
    end

    it "returns only one token" do
      token = FactoryBot.create :access_token, default_attributes
      last_token = described_class.matching_token_for(application, resource_owner, scopes)
      expect(last_token).to eq(token)
    end

    it "accepts nil as resource owner" do
      token = FactoryBot.create :access_token,
                                default_attributes.merge(resource_owner_id: nil, resource_owner_type: nil)
      last_token = described_class.matching_token_for(application, nil, scopes)
      expect(last_token).to eq(token)
    end

    it "excludes revoked tokens" do
      FactoryBot.create :access_token, default_attributes.merge(revoked_at: 1.day.ago)
      last_token = described_class.matching_token_for(application, resource_owner_id, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with a different application" do
      FactoryBot.create :access_token, default_attributes.merge(application: FactoryBot.create(:application))
      last_token = described_class.matching_token_for(application, resource_owner_id, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with a different resource owner" do
      FactoryBot.create :access_token, default_attributes.merge(resource_owner_id: resource_owner.id + 1)
      last_token = described_class.matching_token_for(application, resource_owner_id, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with fewer scopes" do
      FactoryBot.create :access_token, default_attributes.merge(scopes: "public")
      last_token = described_class.matching_token_for(application, resource_owner_id, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with different scopes" do
      FactoryBot.create :access_token, default_attributes.merge(scopes: "public email")
      last_token = described_class.matching_token_for(application, resource_owner, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with additional scopes" do
      FactoryBot.create :access_token, default_attributes.merge(scopes: "public write email")
      last_token = described_class.matching_token_for(application, resource_owner, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with scopes that are not present in server scopes" do
      FactoryBot.create :access_token, default_attributes.merge(
        application: application, scopes: "public read",
      )
      last_token = described_class.matching_token_for(application, resource_owner, scopes)
      expect(last_token).to be_nil
    end

    it "excludes tokens with scopes that are not present in application scopes" do
      application = FactoryBot.create :application, scopes: "private read"
      FactoryBot.create :access_token, default_attributes.merge(
        application: application,
      )
      last_token = described_class.matching_token_for(application, resource_owner, scopes)
      expect(last_token).to be_nil
    end

    it "does not match token if empty scope requested and token/app scopes present" do
      application = FactoryBot.create :application, scopes: "sample:scope"
      app_params = {
        application_id: application.id, scopes: "sample:scope",
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      }
      FactoryBot.create :access_token, app_params
      empty_scopes = Doorkeeper::OAuth::Scopes.from_string("")
      last_token = described_class.matching_token_for(application, resource_owner.id, empty_scopes)
      expect(last_token).to be_nil
    end

    it "matches token if empty scope requested and no token scopes present" do
      empty_scopes = Doorkeeper::OAuth::Scopes.from_string("")
      token = FactoryBot.create :access_token, default_attributes.merge(scopes: empty_scopes)
      last_token = described_class.matching_token_for(application, resource_owner.id, empty_scopes)
      expect(last_token).to eq(token)
    end

    it "returns the last matching token" do
      FactoryBot.create :access_token, default_attributes.merge(created_at: 1.day.ago)
      matching_token = FactoryBot.create :access_token, default_attributes
      FactoryBot.create :access_token, default_attributes.merge(scopes: "public")

      last_token = described_class.matching_token_for(application, resource_owner_id, scopes)
      expect(last_token).to eq(matching_token)
    end
  end

  describe "#as_json" do
    let(:token) { FactoryBot.create(:access_token) }
    let(:token_hash) do
      {
        resource_owner_id: token.resource_owner_id,
        scope: token.scopes,
        expires_in: token.expires_in_seconds,
        application: { uid: token.application.uid },
        created_at: token.created_at.to_i,
      }
    end

    it "returns as_json hash" do
      hash = token_hash

      if Doorkeeper.configuration.polymorphic_resource_owner?
        hash[:resource_owner_type] = token.resource_owner_type
      end

      expect(token.as_json).to match(hash)
    end
  end
end

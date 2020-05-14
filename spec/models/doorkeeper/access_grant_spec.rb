# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::AccessGrant do
  subject(:access_grant) do
    FactoryBot.build(
      :access_grant,
      application: client,
      resource_owner_id: resource_owner.id,
      resource_owner_type: resource_owner.class.name,
    )
  end

  let(:resource_owner) { FactoryBot.build_stubbed(:resource_owner) }
  let(:client) { FactoryBot.build_stubbed(:application) }

  it { expect(access_grant).to be_valid }

  it_behaves_like "an accessible token"
  it_behaves_like "a revocable token"
  it_behaves_like "a unique token" do
    let(:factory_name) { :access_grant }
  end

  context "with hashing enabled" do
    let(:grant) do
      FactoryBot.create :access_grant,
                        resource_owner_id: resource_owner.id,
                        resource_owner_type: resource_owner.class.name
    end

    include_context "with token hashing enabled"

    it "holds a volatile plaintext token when created" do
      expect(grant.plaintext_token).to be_a(String)
      expect(grant.token)
        .to eq(hashed_or_plain_token_func.call(grant.plaintext_token))

      # Finder method only finds the hashed token
      loaded = described_class.find_by(token: grant.token)
      expect(loaded).to eq(grant)
      expect(loaded.plaintext_token).to be_nil
      expect(loaded.token).to eq(grant.token)
    end

    it "does not find_by plain text tokens" do
      expect(described_class.find_by(token: grant.plaintext_token)).to be_nil
    end

    describe "with having a plain text token" do
      let(:plain_text_token) { "plain text token" }

      before do
        # Assume we have a plain text token from before activating the option
        grant.update_column(:token, plain_text_token)
      end

      context "without fallback lookup" do
        it "does not provide lookups with either through by_token" do
          expect(described_class.by_token(plain_text_token)).to eq(nil)
          expect(described_class.by_token(grant.token)).to eq(nil)

          # And it does not touch the token
          grant.reload
          expect(grant.token).to eq(plain_text_token)
        end
      end

      context "with fallback lookup" do
        include_context "with token hashing and fallback lookup enabled"

        it "upgrades a plain token when falling back to it" do
          # Side-effect: This will automatically upgrade the token
          expect(described_class).to receive(:upgrade_fallback_value).and_call_original
          expect(described_class.by_token(plain_text_token))
            .to have_attributes(
              resource_owner_id: grant.resource_owner_id,
              application_id: grant.application_id,
              redirect_uri: grant.redirect_uri,
              expires_in: grant.expires_in,
              scopes: grant.scopes,
            )

          # Will find subsequently by hashing the token
          expect(described_class.by_token(plain_text_token))
            .to have_attributes(
              resource_owner_id: grant.resource_owner_id,
              application_id: grant.application_id,
              redirect_uri: grant.redirect_uri,
              expires_in: grant.expires_in,
              scopes: grant.scopes,
            )

          # Not all the ORM support :id PK
          if grant.respond_to?(:id)
            expect(described_class.by_token(plain_text_token).id).to eq(grant.id)
          end

          # And it modifies the token value
          grant.reload
          expect(grant.token).not_to eq(plain_text_token)
          expect(described_class.find_by(token: plain_text_token)).to eq(nil)
          expect(described_class.find_by(token: grant.token)).not_to be_nil
        end
      end
    end
  end

  describe "validations" do
    it "is invalid without resource_owner_id" do
      access_grant.resource_owner_id = nil
      expect(access_grant).not_to be_valid
    end

    it "is invalid without application_id" do
      access_grant.application_id = nil
      expect(access_grant).not_to be_valid
    end

    it "is invalid without token" do
      access_grant.save
      access_grant.token = nil
      expect(access_grant).not_to be_valid
    end

    it "is invalid without expires_in" do
      access_grant.expires_in = nil
      expect(access_grant).not_to be_valid
    end
  end

  describe ".revoke_all_for" do
    let(:application) { FactoryBot.create :application }
    let(:default_attributes) do
      {
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      }
    end

    it "revokes all tokens for given application and resource owner" do
      FactoryBot.create :access_grant, default_attributes

      described_class.revoke_all_for(application.id, resource_owner)
      expect(described_class.all).to all(be_revoked)
    end

    it "matches application" do
      access_grant_for_different_app = FactoryBot.create(
        :access_grant,
        default_attributes.merge(application: FactoryBot.create(:application)),
      )

      described_class.revoke_all_for(application.id, resource_owner)

      expect(access_grant_for_different_app.reload).not_to be_revoked
    end

    it "matches resource owner" do
      other_resource_owner = FactoryBot.create(:resource_owner)
      access_grant_for_different_owner = FactoryBot.create(
        :access_grant,
        default_attributes.merge(resource_owner_id: other_resource_owner.id),
      )

      described_class.revoke_all_for(application.id, resource_owner)

      expect(access_grant_for_different_owner.reload).not_to be_revoked
    end
  end
end

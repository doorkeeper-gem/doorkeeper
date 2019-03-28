# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::AccessGrant do
  let(:client) { FactoryBot.build_stubbed(:application) }
  let(:clazz) { Doorkeeper::AccessGrant }

  subject { FactoryBot.build(:access_grant, application: client) }

  it { expect(subject).to be_valid }

  it_behaves_like "an accessible token"
  it_behaves_like "a revocable token"
  it_behaves_like "a unique token" do
    let(:factory_name) { :access_grant }
  end

  context "with hashing enabled" do
    let(:grant) { FactoryBot.create :access_grant }
    include_context "with token hashing enabled"

    it "holds a volatile plaintext token when created" do
      expect(grant.plaintext_token).to be_a(String)
      expect(grant.token)
        .to eq(hashed_or_plain_token_func.call(grant.plaintext_token))

      # Finder method only finds the hashed token
      loaded = clazz.find_by(token: grant.token)
      expect(loaded).to eq(grant)
      expect(loaded.plaintext_token).to be_nil
      expect(loaded.token).to eq(grant.token)
    end

    it "does not find_by plain text tokens" do
      expect(clazz.find_by(token: grant.plaintext_token)).to be_nil
    end

    describe "with having a plain text token" do
      let(:plain_text_token) { "plain text token" }

      before do
        # Assume we have a plain text token from before activating the option
        grant.update_column(:token, plain_text_token)
      end

      context "without fallback lookup" do
        it "does not provide lookups with either through by_token" do
          expect(clazz.by_token(plain_text_token)).to eq(nil)
          expect(clazz.by_token(grant.token)).to eq(nil)

          # And it does not touch the token
          grant.reload
          expect(grant.token).to eq(plain_text_token)
        end
      end

      context "with fallback lookup" do
        include_context "with token hashing and fallback lookup enabled"

        it "upgrades a plain token when falling back to it" do
          # Side-effect: This will automatically upgrade the token
          expect(clazz).to receive(:upgrade_fallback_value).and_call_original
          expect(clazz.by_token(plain_text_token)).to eq(grant)

          # Will find subsequently by hashing the token
          expect(clazz.by_token(plain_text_token)).to eq(grant)

          # And it modifies the token value
          grant.reload
          expect(grant.token).not_to eq(plain_text_token)
          expect(clazz.find_by(token: plain_text_token)).to eq(nil)
          expect(clazz.find_by(token: grant.token)).not_to be_nil
        end
      end
    end
  end

  describe "validations" do
    it "is invalid without resource_owner_id" do
      subject.resource_owner_id = nil
      expect(subject).not_to be_valid
    end

    it "is invalid without application_id" do
      subject.application_id = nil
      expect(subject).not_to be_valid
    end

    it "is invalid without token" do
      subject.save
      subject.token = nil
      expect(subject).not_to be_valid
    end

    it "is invalid without expires_in" do
      subject.expires_in = nil
      expect(subject).not_to be_valid
    end
  end

  describe ".revoke_all_for" do
    let(:resource_owner) { double(id: 100) }
    let(:application) { FactoryBot.create :application }
    let(:default_attributes) do
      {
        application: application,
        resource_owner_id: resource_owner.id,
      }
    end

    it "revokes all tokens for given application and resource owner" do
      FactoryBot.create :access_grant, default_attributes

      described_class.revoke_all_for(application.id, resource_owner)

      described_class.all.each do |token|
        expect(token).to be_revoked
      end
    end

    it "matches application" do
      access_grant_for_different_app = FactoryBot.create(
        :access_grant,
        default_attributes.merge(application: FactoryBot.create(:application))
      )

      described_class.revoke_all_for(application.id, resource_owner)

      expect(access_grant_for_different_app.reload).not_to be_revoked
    end

    it "matches resource owner" do
      access_grant_for_different_owner = FactoryBot.create(
        :access_grant,
        default_attributes.merge(resource_owner_id: 90)
      )

      described_class.revoke_all_for application.id, resource_owner

      expect(access_grant_for_different_owner.reload).not_to be_revoked
    end
  end
end

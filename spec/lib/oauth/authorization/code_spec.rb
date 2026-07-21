# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Authorization::Code do
  let(:pre_auth) do
    double(
      :pre_auth,
      client: application,
      redirect_uri: "https://example.com/callback",
      scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
      code_challenge: nil,
      code_challenge_method: nil,
      custom_access_token_attributes: {},
    )
  end
  let(:resource_owner) { FactoryBot.create(:resource_owner) }
  let(:application) { FactoryBot.create(:application) }
  let(:authorization) { described_class.new(pre_auth, resource_owner) }

  describe "#issue_token!" do
    it "memoizes the issued grant" do
      first_grant = authorization.issue_token!

      expect { expect(authorization.issue_token!).to eq(first_grant) }
        .not_to(change { Doorkeeper::AccessGrant.count })
    end

    context "when PKCE is not supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(false)
      end

      it "issues the grant without PKCE attributes" do
        grant = authorization.issue_token!

        expect(grant).to be_persisted
        expect(grant.code_challenge).to be_nil
        expect(grant.code_challenge_method).to be_nil
      end
    end

    context "with a polymorphic resource owner" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          use_polymorphic_resource_owner
        end
        stub_const(
          "PolyAccessGrant",
          Class.new(ApplicationRecord) do
            include Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant
          end,
        )
        config_is_set(:access_grant_class, "PolyAccessGrant")
      end

      it "persists the resource owner association on the grant" do
        grant = authorization.issue_token!

        expect(grant).to be_persisted
        expect(grant.resource_owner).to eq(resource_owner)
      end
    end
  end

  describe "#issue_token! with read replica support" do
    context "when enable_multiple_database_roles is enabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          enable_multiple_database_roles
        end
      end

      it "creates access grant using primary database role" do
        expect(ActiveRecord::Base).to receive(:connected_to).with(role: :writing).and_call_original

        token = authorization.issue_token!
        expect(token).to be_persisted
        expect(token.application_id).to eq(application.id)
      end
    end

    context "when enable_multiple_database_roles is disabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          # enable_multiple_database_roles is disabled by default
        end
      end

      it "creates access grant without explicit role switching" do
        expect(ActiveRecord::Base).not_to receive(:connected_to)

        token = authorization.issue_token!
        expect(token).to be_persisted
      end
    end
  end
end

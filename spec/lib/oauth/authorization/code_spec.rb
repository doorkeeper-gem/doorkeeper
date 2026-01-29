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

  describe "#issue_token! with read replica support" do
    context "when enable_multiple_databases is enabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          enable_multiple_databases
        end
      end

      it "creates access grant using primary database role" do
        expect(ActiveRecord::Base).to receive(:connected_to).with(role: :writing).and_call_original

        token = authorization.issue_token!
        expect(token).to be_persisted
        expect(token.application_id).to eq(application.id)
      end
    end

    context "when enable_multiple_databases is disabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          # enable_multiple_databases is disabled by default
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

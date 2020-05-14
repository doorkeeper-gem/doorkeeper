# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::CodeResponse do
  describe "#redirect_uri" do
    context "when generating the redirect URI for an implicit grant" do
      subject(:redirect_uri) do
        described_class.new(pre_auth, auth, response_on_fragment: true).redirect_uri
      end

      let(:pre_auth) do
        double(
          :pre_auth,
          client: double(:application, id: 1),
          redirect_uri: "http://tst.com/cb",
          state: nil,
          scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        )
      end

      let(:owner) do
        FactoryBot.build_stubbed(:resource_owner)
      end

      let(:auth) do
        Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
          c.issue_token!
          allow(c.token).to receive(:expires_in_seconds).and_return(3600)
        end
      end

      it "includes the remaining TTL of the token relative to the time the token was generated" do
        expect(redirect_uri).to include("expires_in=3600")
      end
    end
  end
end

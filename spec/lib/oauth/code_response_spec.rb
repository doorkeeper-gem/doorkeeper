# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::CodeResponse do
  let(:pre_auth) do
    double(
      :pre_auth,
      client: double(:application, id: 1),
      redirect_uri: "http://tst.com/cb",
      state: "state",
      scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
    )
  end
  let(:owner) { FactoryBot.build_stubbed(:resource_owner) }

  describe "#body" do
    subject(:body) { described_class.new(pre_auth, auth).body }

    context "when auth object is for authorization code flow" do
      let(:auth) do
        Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
      end

      before do
        allow(pre_auth).to receive(:code_challenge).and_return("code_challenge")
        allow(pre_auth).to receive(:code_challenge_method).and_return("plain")
      end

      it "return body response for authorization code" do
        expect(body).to eq({ code: auth.token.plaintext_token, state: pre_auth.state })
      end
    end

    context "when auth object is for implicit grant flow" do
      let(:auth) do
        Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
          c.issue_token!
          allow(c.token).to receive(:expires_in_seconds).and_return(3600)
        end
      end

      it "return body response for access token" do
        expect(body).to eq(
          {
            access_token: auth.token.plaintext_token,
            token_type: auth.token.token_type,
            expires_in: auth.token.expires_in_seconds,
            state: pre_auth.state,
          },
        )
      end
    end
  end

  describe "#redirect_uri" do
    subject(:redirect_uri) do
      described_class.new(pre_auth, auth, response_on_fragment: response_on_fragment).redirect_uri
    end

    context "when generating the redirect URI for an authorization code grant" do
      let(:response_on_fragment) { false }
      let(:auth) do
        Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
      end

      before do
        allow(pre_auth).to receive(:code_challenge).and_return("code_challenge")
        allow(pre_auth).to receive(:code_challenge_method).and_return("plain")
      end

      it "includes the authorization code was generated and state" do
        expect(redirect_uri).to eq("#{pre_auth.redirect_uri}?code=#{auth.token.plaintext_token}&state=#{pre_auth.state}")
      end
    end

    context "when generating the redirect URI for an implicit grant" do
      let(:response_on_fragment) { true }
      let(:auth) do
        Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
          c.issue_token!
          allow(c.token).to receive(:expires_in_seconds).and_return(3600)
        end
      end

      it "includes info of the token was generated and state" do
        expect(redirect_uri).to include("#{pre_auth.redirect_uri}#access_token=#{auth.token.plaintext_token}&" \
          "token_type=#{auth.token.token_type}&expires_in=3600&state=#{pre_auth.state}")
      end
    end
  end
end

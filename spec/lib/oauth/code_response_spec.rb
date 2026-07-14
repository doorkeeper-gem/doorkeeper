# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::CodeResponse do
  let(:application) { FactoryBot.create(:application, scopes: "") }
  let(:owner) { FactoryBot.build_stubbed(:resource_owner) }
  let(:pre_auth) do
    double(
      :pre_auth,
      client: application,
      redirect_uri: "http://tst.com/cb",
      state: "state",
      scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
      custom_access_token_attributes: {},
    )
  end

  describe "#body" do
    subject(:body) { described_class.new(pre_auth, auth).body }

    context "when auth object is for authorization code flow" do
      let(:auth) do
        Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
      end

      before do
        allow(pre_auth).to receive_messages(code_challenge: "code_challenge", code_challenge_method: "plain")
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

    context "when an issuer is configured (RFC 9207)" do
      before { config_is_set(:issuer, "https://auth.example.com") }

      context "when the auth object is for authorization code flow" do
        let(:auth) do
          Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
        end

        before do
          allow(pre_auth).to receive_messages(code_challenge: "code_challenge", code_challenge_method: "plain")
        end

        it "includes the iss parameter" do
          expect(body).to include(iss: "https://auth.example.com")
        end
      end

      context "when the auth object is for implicit grant flow" do
        let(:auth) do
          Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
            c.issue_token!
            allow(c.token).to receive(:expires_in_seconds).and_return(3600)
          end
        end

        it "includes the iss parameter" do
          expect(body).to include(iss: "https://auth.example.com")
        end
      end
    end

    context "when no issuer is configured" do
      let(:auth) do
        Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
      end

      before do
        allow(pre_auth).to receive_messages(code_challenge: "code_challenge", code_challenge_method: "plain")
      end

      it "omits the iss parameter" do
        expect(body).not_to have_key(:iss)
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
        allow(pre_auth).to receive_messages(code_challenge: "code_challenge", code_challenge_method: "plain")
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

    context "when an issuer is configured (RFC 9207)" do
      before { config_is_set(:issuer, "https://auth.example.com") }

      context "with a query response (authorization code grant)" do
        let(:response_on_fragment) { false }
        let(:auth) do
          Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
        end

        before do
          allow(pre_auth).to receive_messages(code_challenge: "code_challenge", code_challenge_method: "plain")
        end

        it "appends the iss parameter to the query" do
          expect(redirect_uri).to include("iss=https%3A%2F%2Fauth.example.com")
        end
      end

      context "with a fragment response (implicit grant)" do
        let(:response_on_fragment) { true }
        let(:auth) do
          Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
            c.issue_token!
            allow(c.token).to receive(:expires_in_seconds).and_return(3600)
          end
        end

        it "appends the iss parameter to the fragment" do
          expect(redirect_uri).to include("iss=https%3A%2F%2Fauth.example.com")
        end
      end

      # RFC 9207 scopes the iss parameter to the authorization response sent to
      # the client. Out-of-band flows render the code/token on a server page for
      # the user to copy - there is no client redirect - so iss is not carried,
      # consistent with state also being absent from the oob payload.
      context "with an out-of-band redirect (authorization code grant)" do
        let(:response_on_fragment) { false }
        let(:auth) do
          Doorkeeper::OAuth::Authorization::Code.new(pre_auth, owner).tap(&:issue_token!)
        end

        before do
          allow(pre_auth).to receive_messages(
            redirect_uri: Doorkeeper::OAuth::NonStandard::IETF_WG_OAUTH2_OOB,
            code_challenge: "code_challenge",
            code_challenge_method: "plain",
          )
        end

        it "omits the iss parameter from the oob payload" do
          expect(redirect_uri).not_to have_key(:iss)
        end
      end

      context "with an out-of-band redirect (implicit grant)" do
        let(:response_on_fragment) { true }
        let(:auth) do
          Doorkeeper::OAuth::Authorization::Token.new(pre_auth, owner).tap do |c|
            c.issue_token!
            allow(c.token).to receive(:expires_in_seconds).and_return(3600)
          end
        end

        before do
          allow(pre_auth).to receive(:redirect_uri)
            .and_return(Doorkeeper::OAuth::NonStandard::IETF_WG_OAUTH2_OOB)
        end

        it "omits the iss parameter from the oob payload" do
          expect(redirect_uri).not_to have_key(:iss)
        end
      end
    end
  end
end

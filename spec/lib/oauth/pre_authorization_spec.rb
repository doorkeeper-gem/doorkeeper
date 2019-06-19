# frozen_string_literal: true

require "spec_helper"

module Doorkeeper::OAuth
  describe PreAuthorization do
    let(:server) do
      server = Doorkeeper.configuration
      allow(server).to receive(:default_scopes).and_return(Scopes.from_string("default"))
      allow(server).to receive(:optional_scopes).and_return(Scopes.from_string("public profile"))
      server
    end

    let(:application) { FactoryBot.create(:application, redirect_uri: "https://app.com/callback") }
    let(:client) { Client.find(application.uid) }

    let :attributes do
      {
        client_id: client.uid,
        response_type: "code",
        redirect_uri: "https://app.com/callback",
        state: "save-this",
      }
    end

    subject do
      PreAuthorization.new(server, attributes)
    end

    it "is authorizable when request is valid" do
      expect(subject).to be_authorizable
    end

    it "accepts code as response type" do
      attributes[:response_type] = "code"
      expect(subject).to be_authorizable
    end

    it "accepts token as response type" do
      allow(server).to receive(:grant_flows).and_return(["implicit"])
      attributes[:response_type] = "token"
      expect(subject).to be_authorizable
    end

    context "when using default grant flows" do
      it 'accepts "code" as response type' do
        attributes[:response_type] = "code"
        expect(subject).to be_authorizable
      end

      it 'accepts "token" as response type' do
        allow(server).to receive(:grant_flows).and_return(["implicit"])
        attributes[:response_type] = "token"
        expect(subject).to be_authorizable
      end
    end

    context "when authorization code grant flow is disabled" do
      before do
        allow(server).to receive(:grant_flows).and_return(["implicit"])
      end

      it 'does not accept "code" as response type' do
        attributes[:response_type] = "code"
        expect(subject).not_to be_authorizable
      end
    end

    context "when implicit grant flow is disabled" do
      before do
        allow(server).to receive(:grant_flows).and_return(["authorization_code"])
      end

      it 'does not accept "token" as response type' do
        attributes[:response_type] = "token"
        expect(subject).not_to be_authorizable
      end
    end

    context "client application does not restrict valid scopes" do
      it "accepts valid scopes" do
        attributes[:scope] = "public"
        expect(subject).to be_authorizable
      end

      it "rejects (globally) non-valid scopes" do
        attributes[:scope] = "invalid"
        expect(subject).not_to be_authorizable
      end

      it "accepts scopes which are permitted for grant_type" do
        allow(server).to receive(:scopes_by_grant_type).and_return(authorization_code: [:public])
        attributes[:scope] = "public"
        expect(subject).to be_authorizable
      end

      it "rejects scopes which are not permitted for grant_type" do
        allow(server).to receive(:scopes_by_grant_type).and_return(authorization_code: [:profile])
        attributes[:scope] = "public"
        expect(subject).not_to be_authorizable
      end
    end

    context "client application restricts valid scopes" do
      let(:application) do
        FactoryBot.create(:application, scopes: Scopes.from_string("public nonsense"))
      end

      it "accepts valid scopes" do
        attributes[:scope] = "public"
        expect(subject).to be_authorizable
      end

      it "rejects (globally) non-valid scopes" do
        attributes[:scope] = "invalid"
        expect(subject).not_to be_authorizable
      end

      it "rejects (application level) non-valid scopes" do
        attributes[:scope] = "profile"
        expect(subject).to_not be_authorizable
      end

      it "accepts scopes which are permitted for grant_type" do
        allow(server).to receive(:scopes_by_grant_type).and_return(authorization_code: [:public])
        attributes[:scope] = "public"
        expect(subject).to be_authorizable
      end

      it "rejects scopes which are not permitted for grant_type" do
        allow(server).to receive(:scopes_by_grant_type).and_return(authorization_code: [:profile])
        attributes[:scope] = "public"
        expect(subject).not_to be_authorizable
      end
    end

    context "when scope is not provided to pre_authorization" do
      before { attributes[:scope] = nil }

      context "when default scopes is provided" do
        it "uses default scopes" do
          allow(server).to receive(:default_scopes).and_return(Scopes.from_string("default"))
          expect(subject).to be_authorizable
          expect(subject.scope).to eq("default")
          expect(subject.scopes).to eq(Scopes.from_string("default"))
        end
      end

      context "when default scopes is none" do
        it "not be authorizable when none default scope" do
          allow(server).to receive(:default_scopes).and_return(Scopes.new)
          expect(subject).not_to be_authorizable
        end
      end
    end

    it "matches the redirect uri against client's one" do
      attributes[:redirect_uri] = "http://nothesame.com"
      expect(subject).not_to be_authorizable
    end

    it "stores the state" do
      expect(subject.state).to eq("save-this")
    end

    it "rejects if response type is not allowed" do
      attributes[:response_type] = "whops"
      expect(subject).not_to be_authorizable
    end

    it "requires an existing client" do
      attributes[:client_id] = nil
      expect(subject).not_to be_authorizable
    end

    it "requires a redirect uri" do
      attributes[:redirect_uri] = nil
      expect(subject).not_to be_authorizable
    end

    describe "as_json" do
      before { subject.authorizable? }

      it { is_expected.to respond_to :as_json }

      shared_examples "returns the pre authorization" do
        it "returns the pre authorization" do
          expect(json[:client_id]).to eq client.uid
          expect(json[:redirect_uri]).to eq subject.redirect_uri
          expect(json[:state]).to eq subject.state
          expect(json[:response_type]).to eq subject.response_type
          expect(json[:scope]).to eq subject.scope
          expect(json[:client_name]).to eq client.name
          expect(json[:status]).to eq I18n.t("doorkeeper.pre_authorization.status")
        end
      end

      context "when attributes param is not passed" do
        let(:json) { subject.as_json }

        include_examples "returns the pre authorization"
      end

      context "when attributes param is passed" do
        context "when attributes is a hash" do
          let(:custom_attributes) { { custom_id: "1234", custom_name: "a pretty good name" } }
          let(:json) { subject.as_json(custom_attributes) }

          include_examples "returns the pre authorization"

          it "merges the attributes in params" do
            expect(json[:custom_id]).to eq custom_attributes[:custom_id]
            expect(json[:custom_name]).to eq custom_attributes[:custom_name]
          end
        end

        context "when attributes is not a hash" do
          let(:json) { subject.as_json(nil) }

          include_examples "returns the pre authorization"
        end
      end
    end
  end
end

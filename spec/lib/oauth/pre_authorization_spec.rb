# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::PreAuthorization do
  subject(:pre_auth) do
    described_class.new(params)
  end

  let(:application) { FactoryBot.create(:application, redirect_uri: "https://app.com/callback") }
  let(:client) { Doorkeeper::OAuth::Client.find(application.uid) }

  let(:params) do
    {
      client_id: client.uid,
      response_type: "code",
      redirect_uri: "https://app.com/callback",
      state: "save-this",
      current_resource_owner: Object.new,
    }
  end

  before do
    allow(Doorkeeper.config).to receive(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("default"))
    allow(Doorkeeper.config).to receive(:optional_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("public profile"))
  end

  it "must call the validations on client and redirect_uri before other validations because they are not redirectable" do
    validation_attributes = described_class.validations.map { |validation| validation[:attribute] }

    expect(validation_attributes).to eq(%i[
      client_id
      client
      client_supports_grant_flow
      resource_owner_authorize_for_client
      redirect_uri
      params
      response_type
      response_mode
      scopes
      code_challenge_method
    ])
  end

  it "is authorizable when request is valid" do
    expect(pre_auth).to be_authorizable
  end

  context "when using default grant flows" do
    it 'accepts "code" as response type' do
      params[:response_type] = "code"
      expect(pre_auth).to be_authorizable
    end

    it 'accepts "token" as response type' do
      allow(Doorkeeper.config).to receive(:grant_flows).and_return(["implicit"])
      params[:response_type] = "token"
      expect(pre_auth).to be_authorizable
    end
  end

  context "when authorization code grant flow is disabled" do
    before do
      allow(Doorkeeper.config).to receive(:grant_flows).and_return(["implicit"])
    end

    it 'does not accept "code" as response type' do
      params[:response_type] = "code"
      expect(pre_auth).not_to be_authorizable
    end
  end

  context "when implicit grant flow is disabled" do
    before do
      allow(Doorkeeper.config).to receive(:grant_flows).and_return(["authorization_code"])
    end

    it 'does not accept "token" as response type' do
      params[:response_type] = "token"
      expect(pre_auth).not_to be_authorizable
    end
  end

  context "with response_mode parameter is provided" do
    context "when response_type is 'code'" do
      before { params[:response_type] = "code" }

      it "sets response_mode as 'query' when it is not provided" do
        params[:response_mode] = ""

        expect(pre_auth).to be_authorizable
        expect(pre_auth.response_mode).to eq("query")
      end

      it 'accepts "query" as response_mode' do
        params[:response_mode] = "query"
        expect(pre_auth).to be_authorizable
      end

      it 'accepts "fragment" as response_mode' do
        params[:response_mode] = "fragment"
        expect(pre_auth).to be_authorizable
      end

      it 'accepts "form_post" as response_mode' do
        params[:response_mode] = "form_post"
        expect(pre_auth).to be_authorizable
      end

      it "does not accept response_mode other than query, fragment, form_post" do
        params[:response_mode] = "other response_mode"

        expect(pre_auth).not_to be_authorizable
      end
    end

    context "when response_type is 'token'" do
      before do
        allow(Doorkeeper.config).to receive(:grant_flows).and_return(["implicit"])
        params[:response_type] = "token"
      end

      it "sets response_mode as 'fragment' when it is not provided" do
        params[:response_mode] = ""

        expect(pre_auth).to be_authorizable
        expect(pre_auth.response_mode).to eq("fragment")
      end

      it 'accepts "fragment" as response_mode' do
        params[:response_mode] = "fragment"
        expect(pre_auth).to be_authorizable
      end

      it 'accepts "form_post" as response_mode' do
        params[:response_mode] = "form_post"
        expect(pre_auth).to be_authorizable
      end

      it 'does not accept "query" response_mode when response_type is "token"' do
        params[:response_mode] = "query"

        expect(pre_auth).not_to be_authorizable
      end
    end
  end

  context "when client application does not restrict valid scopes" do
    it "accepts valid scopes" do
      params[:scope] = "public"
      expect(pre_auth).to be_authorizable
    end

    it "rejects (globally) non-valid scopes" do
      params[:scope] = "invalid"
      expect(pre_auth).not_to be_authorizable
    end

    it "accepts scopes which are permitted for grant_type" do
      allow(Doorkeeper.config).to receive(:scopes_by_grant_type).and_return(authorization_code: [:public])
      params[:scope] = "public"
      expect(pre_auth).to be_authorizable
    end

    it "rejects scopes which are not permitted for grant_type" do
      allow(Doorkeeper.config).to receive(:scopes_by_grant_type).and_return(authorization_code: [:profile])
      params[:scope] = "public"
      expect(pre_auth).not_to be_authorizable
    end
  end

  context "when client application restricts valid scopes" do
    let(:application) do
      FactoryBot.create(:application, scopes: Doorkeeper::OAuth::Scopes.from_string("public nonsense"))
    end

    it "accepts valid scopes" do
      params[:scope] = "public"
      expect(pre_auth).to be_authorizable
    end

    it "rejects (globally) non-valid scopes" do
      params[:scope] = "invalid"
      expect(pre_auth).not_to be_authorizable
    end

    it "rejects (application level) non-valid scopes" do
      params[:scope] = "profile"
      expect(pre_auth).not_to be_authorizable
    end

    it "accepts scopes which are permitted for grant_type" do
      allow(Doorkeeper.config).to receive(:scopes_by_grant_type).and_return(authorization_code: [:public])
      params[:scope] = "public"
      expect(pre_auth).to be_authorizable
    end

    it "rejects scopes which are not permitted for grant_type" do
      allow(Doorkeeper.config).to receive(:scopes_by_grant_type).and_return(authorization_code: [:profile])
      params[:scope] = "public"
      expect(pre_auth).not_to be_authorizable
    end
  end

  context "when scope is not provided to pre_authorization" do
    before { params[:scope] = nil }

    context "when default scopes is provided" do
      it "uses default scopes" do
        allow(Doorkeeper.config).to receive(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.from_string("default_scope"))
        expect(pre_auth).to be_authorizable
        expect(pre_auth.scope).to eq("default_scope")
        expect(pre_auth.scopes).to eq(Doorkeeper::OAuth::Scopes.from_string("default_scope"))
      end
    end

    context "when default scopes is none" do
      it "not be authorizable when none default scope" do
        allow(Doorkeeper.config).to receive(:default_scopes).and_return(Doorkeeper::OAuth::Scopes.new)
        expect(pre_auth).not_to be_authorizable
      end
    end
  end

  it "matches the redirect uri against client's one" do
    params[:redirect_uri] = "http://nothesame.com"
    expect(pre_auth).not_to be_authorizable
  end

  it "stores the state" do
    expect(pre_auth.state).to eq("save-this")
  end

  it "rejects if response type is not allowed" do
    params[:response_type] = "whops"
    expect(pre_auth).not_to be_authorizable
  end

  it "requires an existing client" do
    params[:client_id] = nil
    expect(pre_auth).not_to be_authorizable
  end

  it "requires a redirect uri" do
    params[:redirect_uri] = nil
    expect(pre_auth).not_to be_authorizable
  end

  context "when resource_owner cannot access client application" do
    before { allow(Doorkeeper.configuration).to receive(:authorize_resource_owner_for_client).and_return(->(*_) { false }) }

    it "is not authorizable" do
      expect(pre_auth).not_to be_authorizable
    end
  end

  describe "as_json" do
    before { pre_auth.authorizable? }

    it { is_expected.to respond_to :as_json }

    shared_examples "returns the pre authorization" do
      it "returns the pre authorization" do
        expect(json[:client_id]).to eq client.uid
        expect(json[:redirect_uri]).to eq pre_auth.redirect_uri
        expect(json[:state]).to eq pre_auth.state
        expect(json[:response_type]).to eq pre_auth.response_type
        expect(json[:scope]).to eq pre_auth.scope
        expect(json[:client_name]).to eq client.name
        expect(json[:status]).to eq I18n.t("doorkeeper.pre_authorization.status")
      end
    end

    context "when called without params" do
      let(:json) { pre_auth.as_json }

      include_examples "returns the pre authorization"
    end

    context "when called with params" do
      let(:json) { pre_auth.as_json(foo: "bar") }

      include_examples "returns the pre authorization"
    end
  end

  describe "#form_post_response?" do
    it { is_expected.to respond_to(:form_post_response?) }

    it "return true when response_mode is form_post" do
      params[:response_mode] = "form_post"
      expect(pre_auth.form_post_response?).to be true
    end

    it "when response_mode is other than form_post" do
      params[:response_mode] = "fragment"
      expect(pre_auth.form_post_response?).to be false
    end
  end

  context "when using PKCE params" do
    context "when PKCE is supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(true)
      end

      it "accepts a blank code_challenge" do
        params[:code_challenge] = " "

        expect(pre_auth).to be_authorizable
      end

      it "accepts a code_challenge with a known code_challenge_method" do
        params[:code_challenge] = "a45a9fea-0676-477e-95b1-a40f72ac3cfb"
        params[:code_challenge_method] = "plain"

        expect(pre_auth).to be_authorizable

        params[:code_challenge_method] = "S256"

        expect(pre_auth).to be_authorizable
      end

      it "rejects unknown values for code_challenge_method" do
        params[:code_challenge] = "a45a9fea-0676-477e-95b1-a40f72ac3cfb"
        params[:code_challenge_method] = "unknown"

        expect(pre_auth).not_to be_authorizable
      end
    end

    context "when PKCE is not supported" do
      before do
        allow(Doorkeeper::AccessGrant).to receive(:pkce_supported?).and_return(false)
      end

      it "accepts unknown values for code_challenge_method" do
        params[:code_challenge] = "a45a9fea-0676-477e-95b1-a40f72ac3cfb"
        params[:code_challenge_method] = "unknown"

        expect(pre_auth).to be_authorizable
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Refresh Token Flow" do
  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_refresh_token
    end

    client_exists
  end

  let(:resource_owner) { FactoryBot.create(:resource_owner) }

  describe "issuing a refresh token" do
    before do
      authorization_code_exists application: @client,
                                resource_owner_id: resource_owner.id,
                                resource_owner_type: resource_owner.class.name
    end

    it "client gets the refresh token and refreshes it" do
      post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)

      token = Doorkeeper::AccessToken.first

      expect(json_response).to include(
        "access_token" => token.token,
        "refresh_token" => token.refresh_token,
      )

      expect(@authorization.reload).to be_revoked

      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(client: @client, refresh_token: token.refresh_token)

      new_token = Doorkeeper::AccessToken.last
      expect(json_response).to include(
        "access_token" => new_token.token,
        "refresh_token" => new_token.refresh_token,
      )

      expect(token.token).not_to eq(new_token.token)
      expect(token.refresh_token).not_to eq(new_token.refresh_token)
    end
  end

  describe "refresh token family" do
    def exchange_new_authorization_code
      authorization_code_exists application: @client,
                                resource_owner_id: resource_owner.id,
                                resource_owner_type: resource_owner.class.name
      post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)
      Doorkeeper::AccessToken.by_token(json_response.fetch("access_token"))
    end

    it "starts a family per authorization grant and carries it across refreshes" do
      first_grant_token = exchange_new_authorization_code
      second_grant_token = exchange_new_authorization_code

      expect(first_grant_token.refresh_token_family_id).to be_present
      expect(second_grant_token.refresh_token_family_id).to be_present
      expect(first_grant_token.refresh_token_family_id).not_to eq(second_grant_token.refresh_token_family_id)

      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
        client: @client, refresh_token: first_grant_token.refresh_token,
      )
      refreshed = Doorkeeper::AccessToken.by_token(json_response.fetch("access_token"))

      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
        client: @client, refresh_token: refreshed.refresh_token,
      )
      refreshed_again = Doorkeeper::AccessToken.by_token(json_response.fetch("access_token"))

      expect([refreshed, refreshed_again].map(&:refresh_token_family_id))
        .to all(eq(first_grant_token.refresh_token_family_id))
    end
  end

  describe "refreshing the token" do
    before do
      @token = FactoryBot.create(
        :access_token,
        application: @client,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
    end

    # Regression spec for https://github.com/doorkeeper-gem/doorkeeper/issues/1663
    #
    # reuse_access_token applies to token issuance (e.g. client_credentials,
    # password), not to the refresh grant. Reusing a matching live token here
    # would return the soon-to-expire token the client is refreshing away
    # from, and a matching token from another rotation chain (another
    # device's session) would hand this client that chain's refresh token —
    # revoking one session would then collaterally break the other.
    it "issues a new access token even when reuse_access_token is enabled" do
      config_is_set :reuse_access_token, true

      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
        client: @client, refresh_token: @token.refresh_token,
      )

      new_token = Doorkeeper::AccessToken.last
      expect(new_token).not_to eq(@token)
      expect(json_response).to include(
        "access_token" => new_token.token,
        "refresh_token" => new_token.refresh_token,
      )
    end

    context "when refresh_token revoked on use" do
      it "client requests a token with refresh token" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).not_to be_revoked
      end

      it "client requests a token with expired access token" do
        @token.update_attribute :expires_in, -100
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).not_to be_revoked
      end

      # Regression specs for https://github.com/doorkeeper-gem/doorkeeper/issues/1787
      #
      # Rotation deliberately leaves the previous refresh token usable until
      # the rotated access token is first used at a protected resource
      # (AccessToken#revoke_previous_refresh_token!, pinned from the other
      # side in spec/requests/endpoints/introspection_spec.rb). The grace
      # period lets a client retry a refresh whose response was lost in
      # transit; revoking on the second request would lock such clients out.
      it "accepts the same refresh token again while the rotated access token is unused" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )
        first_rotation = Doorkeeper::AccessToken.last

        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(Doorkeeper::AccessToken.last).not_to eq(first_rotation)
        expect(@token.reload).not_to be_revoked
      end

      # Refresh tokens carry no expiry of their own: expires_in bounds only
      # the access token, so an unused, unrevoked refresh token stays
      # exchangeable no matter how long ago its access token expired.
      it "accepts a refresh token whose access token expired long ago" do
        @token.update_attribute :created_at, 5.years.ago
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
      end
    end

    context "when refresh_token revoked on refresh_token request" do
      before do
        allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
      end

      it "client request a token with refresh token" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).to be_revoked
      end

      it "client request a token with expired access token" do
        @token.update_attribute :expires_in, -100
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).to be_revoked
      end
    end

    context "with public & private clients" do
      let(:public_client) do
        FactoryBot.create(
          :application,
          confidential: false,
        )
      end

      let(:token_for_private_client) do
        FactoryBot.create(
          :access_token,
          application: @client,
          resource_owner_id: resource_owner.id,
          resource_owner_type: resource_owner.class.name,
          use_refresh_token: true,
        )
      end

      let(:token_for_public_client) do
        FactoryBot.create(
          :access_token,
          application: public_client,
          resource_owner_id: resource_owner.id,
          resource_owner_type: resource_owner.class.name,
          use_refresh_token: true,
        )
      end

      it "issues a new token without client_secret when refresh token was issued to a public client" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client_id: public_client.uid,
          refresh_token: token_for_public_client.refresh_token,
        )

        new_token = Doorkeeper::AccessToken.last
        expect(json_response).to include(
          "access_token" => new_token.token,
          "refresh_token" => new_token.refresh_token,
        )
      end

      it "returns an error without credentials" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(refresh_token: token_for_private_client.refresh_token)

        expect(json_response).to include("error" => "invalid_grant")
      end

      it "returns an error with wrong credentials" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client_id: "1",
          client_secret: "1",
          refresh_token: token_for_private_client.refresh_token,
        )
        expect(json_response).to match(
          "error" => "invalid_client",
          "error_description" => an_instance_of(String),
        )
      end
    end

    it "client gets an error for invalid refresh token" do
      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(client: @client, refresh_token: "invalid")

      expect(json_response).to match(
        "error" => "invalid_grant",
        "error_description" => an_instance_of(String),
      )
    end

    it "client gets an error for revoked access token" do
      @token.revoke
      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(client: @client, refresh_token: @token.refresh_token)

      expect(json_response).to match(
        "error" => "invalid_grant",
        "error_description" => an_instance_of(String),
      )
    end

    it "second of simultaneous client requests get an error for revoked access token" do
      allow_any_instance_of(Doorkeeper::AccessToken).to receive(:revoked?).and_return(false, true)
      post refresh_token_endpoint_url, params: refresh_token_endpoint_params(client: @client, refresh_token: @token.refresh_token)

      expect(json_response).to match(
        "error" => "invalid_grant",
        "error_description" => an_instance_of(String),
      )
    end
  end

  # Regression specs for https://github.com/doorkeeper-gem/doorkeeper/issues/1771
  #
  # RFC 6749 §6: the refresh token keeps the scope originally granted by the
  # resource owner. A client may narrow the access token it gets back from a
  # refresh, and a later refresh may go back up to the granted scope, whether
  # by omitting the scope parameter or by asking for the granted scope again.
  describe "narrowing and restoring the scope across refreshes" do
    before do
      default_scopes_exist :public
      optional_scopes_exist :write, :update
      authorization_code_exists application: @client,
                                resource_owner_id: resource_owner.id,
                                resource_owner_type: resource_owner.class.name,
                                scopes: "public write"
    end

    def refresh(token, scope: nil)
      params = refresh_token_endpoint_params(client: @client, refresh_token: token.refresh_token)
      params[:scope] = scope if scope
      post refresh_token_endpoint_url, params: params
      Doorkeeper::AccessToken.last
    end

    it "lets a narrowed chain return to the granted scope" do
      post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)
      granted = Doorkeeper::AccessToken.last
      expect(granted.scopes.to_s).to eq("public write")
      expect(granted.refresh_token_scopes.to_s).to eq("public write")

      narrowed = refresh(granted, scope: "public")
      expect(json_response).to include("scope" => "public", "refresh_token" => narrowed.refresh_token)
      expect(narrowed.scopes.to_s).to eq("public")
      expect(narrowed.refresh_token_scopes.to_s).to eq("public write")

      restored = refresh(narrowed)
      expect(json_response).to include("scope" => "public write", "refresh_token" => restored.refresh_token)
      expect(restored.scopes.to_s).to eq("public write")

      explicit = refresh(restored, scope: "public write")
      expect(json_response).to include("scope" => "public write", "refresh_token" => explicit.refresh_token)
    end

    it "still refuses a scope the resource owner never granted" do
      post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)
      narrowed = refresh(Doorkeeper::AccessToken.last, scope: "public")

      refresh(narrowed, scope: "public write update")

      expect(response).to have_http_status(:bad_request)
      expect(json_response).to include("error" => "invalid_scope")
    end

    context "without the refresh_token_scopes column" do
      before do
        allow(Doorkeeper::AccessToken).to receive(:refresh_token_scopes_supported?).and_return(false)
      end

      it "keeps narrowing the refresh token along with the access token" do
        post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)
        narrowed = refresh(Doorkeeper::AccessToken.last, scope: "public")

        restored = refresh(narrowed)
        expect(json_response).to include("scope" => "public", "refresh_token" => restored.refresh_token)

        refresh(restored, scope: "public write")
        expect(json_response).to include("error" => "invalid_scope")
      end
    end
  end

  # Regression specs for https://github.com/doorkeeper-gem/doorkeeper/issues/1686
  #
  # In `application/x-www-form-urlencoded` payloads (and query strings) a "+"
  # is the encoding of a space, so Rack turns `scope=public+write` into the
  # space-delimited scope list "public write" before Doorkeeper sees it. A
  # literal "+" inside a scope value has to be sent percent-encoded as %2B and
  # names a different, single scope (RFC 6749 §3.3 allows "+" in scope tokens).
  describe "refreshing the token with '+' in the scope parameter" do
    before do
      @token = FactoryBot.create(
        :access_token,
        application: @client,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
        scopes: "public write",
      )
    end

    it "treats '+' between scopes as an encoded space" do
      post refresh_token_endpoint_url,
           params: raw_form_refresh_params(scope: "public+write"),
           headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

      new_token = Doorkeeper::AccessToken.last
      expect(json_response).to include(
        "access_token" => new_token.token,
        "scope" => "public write",
      )
    end

    it "treats a percent-encoded '+' as part of a single scope name and rejects it when unknown" do
      post refresh_token_endpoint_url,
           params: raw_form_refresh_params(scope: "public%2Bwrite"),
           headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

      expect(json_response).to include("error" => "invalid_scope")
    end

    def raw_form_refresh_params(scope:)
      "grant_type=refresh_token" \
        "&client_id=#{CGI.escape(@client.uid)}" \
        "&client_secret=#{CGI.escape(@client.secret)}" \
        "&refresh_token=#{CGI.escape(@token.refresh_token)}" \
        "&scope=#{scope}"
    end
  end

  context "when refreshing the token with multiple sessions (devices)" do
    before do
      # enable password auth to simulate other devices
      config_is_set(:grant_flows, ["password"])
      config_is_set(:resource_owner_from_credentials) do
        User.authenticate! params[:username], params[:password]
      end
      create_resource_owner
      _another_token = post token_endpoint_url, params: password_token_endpoint_params(
        client: @client, resource_owner: resource_owner,
      )
      last_token.update(created_at: 5.seconds.ago)

      @token = FactoryBot.create(
        :access_token,
        application: @client,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
      @token.update_attribute :expires_in, -100
    end

    context "when refresh_token revoked on use" do
      it "client request a token after creating another token with the same user" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("refresh_token" => last_token.refresh_token)
        expect(@token.reload).not_to be_revoked
      end
    end

    context "when refresh_token revoked on refresh_token request" do
      before do
        allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
      end

      it "client request a token after creating another token with the same user" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("refresh_token" => last_token.refresh_token)
        expect(@token.reload).to be_revoked
      end
    end

    context "when custom_access_token_expires_in is configured" do
      before do
        @token.update_attribute :expires_in, 3600
      end

      # https://github.com/doorkeeper-gem/doorkeeper/issues/1364: the TTL a
      # grant type was given must not be replaced by access_token_expires_in
      # on refresh when the callable does not decide for refresh_token.
      it "keeps the expiry of the refreshed token when the callable returns nil" do
        config_is_set(:custom_access_token_expires_in) do |context|
          1.hour if context.grant_type == Doorkeeper::OAuth::PASSWORD
        end

        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("expires_in" => 3600)
        expect(Doorkeeper::AccessToken.last.expires_in).to eq(3600)
      end

      it "uses the expiry the callable returns for the refresh_token grant" do
        config_is_set(:custom_access_token_expires_in) do |context|
          10.minutes if context.grant_type == Doorkeeper::OAuth::REFRESH_TOKEN
        end

        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("expires_in" => 600)
        expect(Doorkeeper::AccessToken.last.expires_in).to eq(600)
      end
    end

    context "when public_client_access_token_expires_in is configured" do
      before do
        config_is_set(:public_client_access_token_expires_in, 10.minutes)
        @token.update_attribute :expires_in, nil
      end

      it "caps the expiry of the token refreshed by a public client" do
        @client.update_attribute :confidential, false

        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client_id: @client.uid, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("expires_in" => 600)
        expect(Doorkeeper::AccessToken.last.expires_in).to eq(600)
      end

      it "keeps the expiry of the token refreshed by a confidential client" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).not_to have_key("expires_in")
        expect(Doorkeeper::AccessToken.last.expires_in).to be_nil
      end
    end

    context "when custom_access_token_attributes are configured" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          custom_access_token_attributes [:tenant_name]
        end

        @token = FactoryBot.create(
          :access_token,
          application: @client,
          resource_owner_id: resource_owner.id,
          resource_owner_type: resource_owner.class.name,
          use_refresh_token: true,
          tenant_name: "Tenant 1",
        )
      end

      it "copies custom attributes from the previous token into the new token" do
        post refresh_token_endpoint_url, params: refresh_token_endpoint_params(
          client: @client, refresh_token: @token.refresh_token,
        )

        new_token = Doorkeeper::AccessToken.last
        expect(new_token.tenant_name).to eq("Tenant 1")
      end
    end

    def last_token
      Doorkeeper::AccessToken.last_authorized_token_for(
        @client.id, resource_owner,
      )
    end
  end
end

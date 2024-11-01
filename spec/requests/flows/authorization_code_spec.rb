# frozen_string_literal: true

require "spec_helper"

feature "Authorization Code Flow" do
  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    client_exists
    create_resource_owner
    sign_in
  end

  scenario "resource owner authorizes the client" do
    visit authorization_endpoint_url(client: @client)
    click_on "Authorize"

    access_grant_should_exist_for(@client, @resource_owner)

    i_should_be_on_client_callback(@client)

    url_should_have_param("code", Doorkeeper::AccessGrant.first.token)
    url_should_not_have_param("state")
    url_should_not_have_param("error")
  end

  context "when configured to check application supported grant flow" do
    before do
      config_is_set(:allow_grant_flow_for_client, ->(_grant_flow, client) { client.name == "admin" })
    end

    scenario "forbids the request when doesn't satisfy condition" do
      @client.update(name: "sample app")

      visit authorization_endpoint_url(client: @client)

      i_should_see_translated_error_message("unauthorized_client")
    end

    scenario "allows the request when satisfies condition" do
      @client.update(name: "admin")

      visit authorization_endpoint_url(client: @client)
      i_should_not_see_translated_error_message("unauthorized_client")
      click_on "Authorize"

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      access_token_should_exist_for(@client, @resource_owner)

      expect(json_response).to match(
        "access_token" => Doorkeeper::AccessToken.first.token,
        "token_type" => "Bearer",
        "expires_in" => 7200,
        "scope" => "default",
        "created_at" => an_instance_of(Integer),
      )
    end
  end

  context "with grant hashing enabled" do
    background do
      config_is_set(:token_secret_strategy, ::Doorkeeper::SecretStoring::Sha256Hash)
    end

    def authorize(redirect_url)
      @client.redirect_uri = redirect_url
      @client.save!
      visit authorization_endpoint_url(client: @client)
      click_on "Authorize"

      access_grant_should_exist_for(@client, @resource_owner)

      code = current_params["code"]
      expect(code).not_to be_nil

      hashed_code = Doorkeeper::AccessGrant.secret_strategy.transform_secret code
      expect(hashed_code).to eq Doorkeeper::AccessGrant.first.token

      [code, hashed_code]
    end

    scenario "using redirect_url urn:ietf:wg:oauth:2.0:oob" do
      code, hashed_code = authorize("urn:ietf:wg:oauth:2.0:oob")
      expect(code).not_to eq(hashed_code)
      i_should_see "Authorization code:"
      i_should_see code
      i_should_not_see hashed_code
    end

    scenario "using redirect_url urn:ietf:wg:oauth:2.0:oob:auto" do
      code, hashed_code = authorize("urn:ietf:wg:oauth:2.0:oob:auto")
      expect(code).not_to eq(hashed_code)
      i_should_see "Authorization code:"
      i_should_see code
      i_should_not_see hashed_code
    end
  end

  scenario "resource owner authorizes using oob url" do
    @client.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    @client.save!
    visit authorization_endpoint_url(client: @client)
    click_on "Authorize"

    access_grant_should_exist_for(@client, @resource_owner)

    url_should_have_param("code", Doorkeeper::AccessGrant.first.token)
    i_should_see "Authorization code:"
    i_should_see Doorkeeper::AccessGrant.first.token
  end

  scenario "resource owner authorizes the client with state parameter set" do
    visit authorization_endpoint_url(client: @client, state: "return-me")
    click_on "Authorize"
    url_should_have_param("code", Doorkeeper::AccessGrant.first.token)
    url_should_have_param("state", "return-me")
    url_should_not_have_param("code_challenge_method")
  end

  scenario "resource owner requests an access token without authorization code" do
    create_access_token "", @client

    access_token_should_not_exist

    expect(Doorkeeper::AccessToken.count).to be_zero

    expect(json_response).to match(
      "error" => "invalid_request",
      "error_description" => translated_invalid_request_error_message(:missing_param, :code),
    )
  end

  scenario "resource owner requests an access token with authorization code" do
    visit authorization_endpoint_url(client: @client)
    click_on "Authorize"

    authorization_code = Doorkeeper::AccessGrant.first.token
    create_access_token authorization_code, @client

    access_token_should_exist_for(@client, @resource_owner)

    expect(json_response).to match(
      "access_token" => Doorkeeper::AccessToken.first.token,
      "token_type" => "Bearer",
      "expires_in" => 7200,
      "scope" => "default",
      "created_at" => an_instance_of(Integer),
    )
  end

  scenario "resource owner requests an access token with authorization code but without secret" do
    visit authorization_endpoint_url(client: @client)
    click_on "Authorize"

    authorization_code = Doorkeeper::AccessGrant.first.token
    page.driver.post token_endpoint_url(
      code: authorization_code,
      client_id: @client.uid,
      redirect_uri: @client.redirect_uri,
    )

    expect(Doorkeeper::AccessToken.count).to be_zero

    expect(json_response).to match(
      "error" => "invalid_client",
      "error_description" => translated_error_message(:invalid_client),
    )
  end

  scenario "resource owner requests an access token with authorization code but without client id" do
    visit authorization_endpoint_url(client: @client)
    click_on "Authorize"

    authorization_code = Doorkeeper::AccessGrant.first.token
    page.driver.post token_endpoint_url(
      code: authorization_code,
      client_secret: @client.secret,
      redirect_uri: @client.redirect_uri,
    )

    expect(Doorkeeper::AccessToken.count).to be_zero

    expect(json_response).to match(
      "error" => "invalid_client",
      "error_description" => translated_error_message(:invalid_client),
    )
  end

  scenario "silently authorizes if active matching token exists" do
    default_scopes_exist :public, :write

    access_token_exists application: @client,
                        expires_in: 10_000,
                        resource_owner_id: @resource_owner.id,
                        resource_owner_type: @resource_owner.class.name,
                        scopes: "public write"

    visit authorization_endpoint_url(client: @client, scope: "public write")

    response_status_should_be 200
    i_should_not_see "Authorize"
  end

  context "with PKCE" do
    context "when plain" do
      let(:code_challenge) { "a45a9fea-0676-477e-95b1-a40f72ac3cfb" }
      let(:code_verifier) { "a45a9fea-0676-477e-95b1-a40f72ac3cfb" }

      scenario "resource owner authorizes the client with code_challenge parameter set" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "plain",
        )
        click_on "Authorize"

        url_should_have_param("code", Doorkeeper::AccessGrant.first.token)
        url_should_not_have_param("code_challenge_method")
        url_should_not_have_param("code_challenge")
      end

      scenario "mobile app requests an access token with authorization code but not pkce token" do
        visit authorization_endpoint_url(client: @client)
        click_on "Authorize"

        url_should_have_param("code", Doorkeeper::AccessGrant.first.token)
      end

      scenario "mobile app requests an access token with authorization code and plain code challenge method" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "plain",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        create_access_token authorization_code, @client, code_verifier

        access_token_should_exist_for(@client, @resource_owner)

        expect(json_response).to match(
          "access_token" => Doorkeeper::AccessToken.first.token,
          "token_type" => "Bearer",
          "expires_in" => 7200,
          "scope" => "default",
          "created_at" => an_instance_of(Integer),
        )
      end

      scenario "mobile app requests an access token with authorization code but without code_verifier" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "plain",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        create_access_token authorization_code, @client, nil

        expect(json_response).to match(
          "error" => "invalid_request",
          "error_description" => translated_invalid_request_error_message(:missing_param, :code_verifier),
        )
      end

      scenario "mobile app requests an access token with authorization code with wrong code_verifier" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "plain",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        create_access_token authorization_code, @client, "wrong_code_verifier"

        expect(json_response).not_to include("access_token")
        expect(json_response).to match(
          "error" => "invalid_grant",
          "error_description" => translated_error_message(:invalid_grant),
        )
      end
    end

    context "when S256" do
      let(:code_challenge) { "Oz733NtQ0rJP8b04fgZMJMwprn6Iw8sMCT_9bR1q4tA" }
      let(:code_verifier) { "a45a9fea-0676-477e-95b1-a40f72ac3cfb" }

      scenario "resource owner authorizes the client with code_challenge parameter set" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
        )
        click_on "Authorize"

        url_should_have_param("code", Doorkeeper::AccessGrant.first.token)
        url_should_not_have_param("code_challenge_method")
        url_should_not_have_param("code_challenge")
      end

      scenario "mobile app requests an access token with authorization code and S256 code challenge method" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        create_access_token authorization_code, @client, code_verifier

        access_token_should_exist_for(@client, @resource_owner)

        expect(json_response).to match(
          "access_token" => Doorkeeper::AccessToken.first.token,
          "token_type" => "Bearer",
          "expires_in" => 7200,
          "scope" => "default",
          "created_at" => an_instance_of(Integer),
        )
      end

      scenario "mobile app requests an access token with authorization code and without secret" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        page.driver.post token_endpoint_url(
          code: authorization_code,
          client_id: @client.uid,
          redirect_uri: @client.redirect_uri,
          code_verifier: code_verifier,
        )

        expect(json_response).to match(
          "error" => "invalid_client",
          "error_description" => translated_error_message(:invalid_client),
        )
      end

      scenario "mobile app requests an access token with authorization code and without secret but is marked as not confidential" do
        @client.update_attribute :confidential, false
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: "S256")
        click_on "Authorize"

        authorization_code = current_params["code"]
        page.driver.post token_endpoint_url(
          code: authorization_code,
          client_id: @client.uid,
          redirect_uri: @client.redirect_uri,
          code_verifier: code_verifier,
        )

        expect(json_response).to match(
          "access_token" => Doorkeeper::AccessToken.first.token,
          "token_type" => "Bearer",
          "expires_in" => 7200,
          "scope" => "default",
          "created_at" => an_instance_of(Integer),
        )
      end

      scenario "mobile app requests an access token with authorization code but no code verifier" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        create_access_token authorization_code, @client

        expect(json_response).not_to include("access_token")
        expect(json_response).to match(
          "error" => "invalid_request",
          "error_description" => translated_invalid_request_error_message(:missing_param, :code_verifier),
        )
      end

      scenario "mobile app requests an access token with authorization code with wrong verifier" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        create_access_token authorization_code, @client, "incorrect-code-verifier"

        expect(json_response).to match(
          "error" => "invalid_grant",
          "error_description" => translated_error_message(:invalid_grant),
        )
      end

      scenario "code_challenge_methhod in token request is totally ignored" do
        visit authorization_endpoint_url(
          client: @client,
          code_challenge: code_challenge,
          code_challenge_method: "S256",
        )
        click_on "Authorize"

        authorization_code = current_params["code"]
        page.driver.post token_endpoint_url(
          code: authorization_code,
          client: @client,
          code_verifier: code_challenge,
          code_challenge_method: "plain",
        )

        expect(json_response).to match(
          "error" => "invalid_grant",
          "error_description" => translated_error_message(:invalid_grant),
        )
      end

      scenario "expects to set code_challenge_method explicitly without fallback" do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge)
        expect(page).to have_content("The code_challenge_method must be one of plain, S256.")
      end
    end
  end

  context "when application scopes are present and no scope is passed" do
    background do
      @client.update(scopes: "public write read default")
    end

    scenario "scope is invalid because default scope is different from application scope" do
      default_scopes_exist :admin
      visit authorization_endpoint_url(client: @client)
      response_status_should_be 400
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :invalid_scope
    end

    scenario "access grant have scopes which are common in application scopees and default scopes" do
      default_scopes_exist :public, :write
      visit authorization_endpoint_url(client: @client)
      click_on "Authorize"
      access_grant_should_exist_for(@client, @resource_owner)
      access_grant_should_have_scopes :public, :write
    end
  end

  context "with scopes" do
    background do
      default_scopes_exist :public
      optional_scopes_exist :write
    end

    scenario "resource owner authorizes the client with default scopes" do
      visit authorization_endpoint_url(client: @client)
      click_on "Authorize"
      access_grant_should_exist_for(@client, @resource_owner)
      access_grant_should_have_scopes :public
    end

    scenario "resource owner authorizes the client with required scopes" do
      visit authorization_endpoint_url(client: @client, scope: "public write")
      click_on "Authorize"
      access_grant_should_have_scopes :public, :write
    end

    scenario "resource owner authorizes the client with required scopes (without defaults)" do
      visit authorization_endpoint_url(client: @client, scope: "write")
      click_on "Authorize"
      access_grant_should_have_scopes :write
    end

    scenario "new access token matches required scopes" do
      visit authorization_endpoint_url(client: @client, scope: "public write")
      click_on "Authorize"

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      access_token_should_exist_for(@client, @resource_owner)
      access_token_should_have_scopes :public, :write
    end

    scenario "returns new token if scopes have changed" do
      client_is_authorized(@client, @resource_owner, scopes: "public write")
      visit authorization_endpoint_url(client: @client, scope: "public")
      click_on "Authorize"

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      expect(Doorkeeper::AccessToken.count).to be(2)

      expect(json_response).to include("access_token" => Doorkeeper::AccessToken.last.token)
    end

    scenario "resource owner authorizes the client with extra scopes" do
      client_is_authorized(@client, @resource_owner, scopes: "public")
      visit authorization_endpoint_url(client: @client, scope: "public write")
      click_on "Authorize"

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      expect(Doorkeeper::AccessToken.count).to be(2)

      expect(json_response).to include("access_token" => Doorkeeper::AccessToken.last.token)
      access_token_should_have_scopes :public, :write
    end
  end

  context "when two requests sent" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
      end

      client_exists
    end

    describe "issuing a refresh token" do
      let(:resource_owner) { FactoryBot.create(:resource_owner) }

      before do
        authorization_code_exists application: @client,
                                  resource_owner_id: resource_owner.id,
                                  resource_owner_type: resource_owner.class.name
      end

      it "second of simultaneous client requests get an error for revoked access token" do
        authorization_code = Doorkeeper::AccessGrant.first.token
        allow_any_instance_of(Doorkeeper::AccessGrant)
          .to receive(:revoked?).and_return(false, true)

        page.driver.post token_endpoint_url(code: authorization_code, client: @client)

        expect(json_response).to match(
          "error" => "invalid_grant",
          "error_description" => translated_error_message(:invalid_grant),
        )
      end
    end
  end

  context "when custom_access_token_attributes are configured" do
    let(:resource_owner) { FactoryBot.create(:resource_owner) }
    let(:client) { client_exists }
    let(:grant) do
      authorization_code_exists(
         application: client,
         resource_owner_id: resource_owner.id,
         resource_owner_type: resource_owner.class.name,
         tenant_name: "Tenant 1",
       )
    end

    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        custom_access_token_attributes [:tenant_name]
      end
    end

    it "copies custom attributes from the grant into the token" do
      page.driver.post token_endpoint_url(code: grant.token, client: client)

      access_token = Doorkeeper::AccessToken.find_by(token: json_response["access_token"])
      expect(access_token.tenant_name).to eq("Tenant 1")
    end
  end
end

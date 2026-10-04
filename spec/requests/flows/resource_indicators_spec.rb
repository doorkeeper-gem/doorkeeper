# frozen_string_literal: true

require "spec_helper"

feature "Resource Indicators (RFC 8707) Flow" do
  let(:resource_uri) { "https://api.example.com/" }

  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    config_is_set(
      :resource_indicator_validator,
      lambda { |indicators, _client|
        indicators.all? { |r| r.start_with?("https://") }
      },
    )
    client_exists
    create_resource_owner
    sign_in
  end

  scenario "authorization code flow with resource indicator audience-restricts the token" do
    # 1. Authorization request with resource parameter
    params = {
      client_id: @client.uid,
      redirect_uri: @client.redirect_uri,
      response_type: "code",
      scope: "default",
      resource: resource_uri,
    }
    visit "/oauth/authorize?#{Rack::Utils.build_query(params)}"

    # Verify the page rendered the authorize form (not an error)
    expect(page).to have_button("Authorize")
    click_on "Authorize"

    # 2. Grant is created with the resource indicator persisted
    grant = Doorkeeper::AccessGrant.first
    expect(grant).to be_present
    expect(grant.resource).to eq(resource_uri)

    # 3. Exchange the code for a token, requesting the same resource
    page.driver.post token_endpoint_url, {
      grant_type: "authorization_code",
      code: grant.token,
      client_id: @client.uid,
      client_secret: @client.secret,
      redirect_uri: @client.redirect_uri,
      resource: resource_uri,
    }

    expect(page.driver.response.status).to eq(200)
    token_response = JSON.parse(page.driver.response.body)
    expect(token_response["access_token"]).to be_present

    # 4. The issued access token is audience-restricted
    access_token = Doorkeeper::AccessToken.find_by(token: token_response["access_token"])
    expect(access_token.resource).to eq(resource_uri)
  end

  scenario "implicit flow with resource indicator audience-restricts the token" do
    config_is_set(:grant_flows, ["implicit"])

    params = {
      client_id: @client.uid,
      redirect_uri: @client.redirect_uri,
      response_type: "token",
      scope: "default",
      resource: resource_uri,
    }
    visit "/oauth/authorize?#{Rack::Utils.build_query(params)}"

    expect(page).to have_button("Authorize")
    click_on "Authorize"

    # The token is issued straight from the authorization endpoint, with the
    # resource carried over since there is no grant to inherit it from.
    access_token = Doorkeeper::AccessToken.first
    expect(access_token).to be_present
    expect(access_token.resource).to eq(resource_uri)

    fragment = Rack::Utils.parse_query(URI.parse(page.current_url).fragment)
    expect(fragment["access_token"]).to eq(access_token.token)
  end

  # RFC 8707 §2.2 (Figures 3-6): the token request restricts the access token
  # to one of the granted resources, and the refresh token issued with it can
  # still be used for the others.
  context "when the grant covers several resources" do
    let(:calendar) { "https://cal.example.com/" }
    let(:contacts) { "https://contacts.example.com/" }

    background do
      config_is_set(:refresh_token_enabled, true)
    end

    def authorize_for(*resources)
      params = {
        client_id: @client.uid,
        redirect_uri: @client.redirect_uri,
        response_type: "code",
        scope: "default",
        resource: resources,
      }
      visit "/oauth/authorize?#{params.to_query}"
      click_on "Authorize"

      Doorkeeper::AccessGrant.last
    end

    def exchange(grant, **params)
      page.driver.post token_endpoint_url, {
        grant_type: "authorization_code",
        code: grant.token,
        client_id: @client.uid,
        client_secret: @client.secret,
        redirect_uri: @client.redirect_uri,
        **params,
      }
      JSON.parse(page.driver.response.body)
    end

    def refresh(refresh_token, **params)
      page.driver.post token_endpoint_url, {
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: @client.uid,
        client_secret: @client.secret,
        **params,
      }
      JSON.parse(page.driver.response.body)
    end

    def audience_of(token_response)
      Doorkeeper::AccessToken.by_token(token_response["access_token"]).resource
    end

    scenario "a token restricted to one resource is refreshed for another one" do
      grant = authorize_for(calendar, contacts)
      expect(grant.resource).to eq("#{calendar} #{contacts}")

      calendar_token = exchange(grant, resource: calendar)
      expect(audience_of(calendar_token)).to eq(calendar)

      contacts_token = refresh(calendar_token["refresh_token"], resource: contacts)
      expect(page.driver.response.status).to eq(200)
      expect(audience_of(contacts_token)).to eq(contacts)

      # The rotated refresh token is still bound to the whole grant.
      calendar_again = refresh(contacts_token["refresh_token"], resource: calendar)
      expect(page.driver.response.status).to eq(200)
      expect(audience_of(calendar_again)).to eq(calendar)
    end

    scenario "a refresh never reaches a resource outside the grant" do
      calendar_token = exchange(authorize_for(calendar, contacts), resource: calendar)

      response = refresh(calendar_token["refresh_token"], resource: "https://files.example.com/")

      expect(page.driver.response.status).to eq(400)
      expect(response["error"]).to eq("invalid_target")
    end

    scenario "a refresh without a resource keeps the audience of the token being refreshed" do
      calendar_token = exchange(authorize_for(calendar, contacts), resource: calendar)

      refreshed = refresh(calendar_token["refresh_token"])

      expect(page.driver.response.status).to eq(200)
      expect(audience_of(refreshed)).to eq(calendar)
    end
  end
end

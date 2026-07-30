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
end

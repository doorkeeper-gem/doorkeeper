# frozen_string_literal: true

require "spec_helper"

feature "Private API" do
  background do
    @client   = FactoryBot.create(:application)
    @resource = User.create!(name: "Joe", password: "sekret")
    @token    = client_is_authorized(@client, @resource)
  end

  scenario "client requests protected resource with valid token" do
    with_access_token_header @token.token
    visit "/full_protected_resources"
    expect(page.body).to have_content("index")
  end

  scenario "client requests protected resource with disabled header authentication" do
    config_is_set :access_token_methods, [:from_access_token_param]
    with_access_token_header @token.token
    visit "/full_protected_resources"
    response_status_should_be 401
  end

  scenario "client attempts to request protected resource with invalid token" do
    with_access_token_header "invalid"
    visit "/full_protected_resources"
    response_status_should_be 401
  end

  # RFC 6750 §2 forbids transmitting the token by more than one method, and
  # §3.1 answers it with invalid_request (400), not invalid_token (401).
  scenario "client attempts to transmit tokens by more than one method" do
    with_access_token_header @token.token
    visit "/full_protected_resources?access_token=another-token"
    response_status_should_be 400
  end

  # §2 forbids using more than one method, not presenting two different
  # tokens, so repeating one token across two methods is refused as well.
  scenario "client repeats the same token across two transmission methods" do
    with_access_token_header @token.token
    visit "/full_protected_resources?access_token=#{@token.token}"
    response_status_should_be 400
  end

  # The form-encoded body (§2.2) and the URI query (§2.3) are two methods, but
  # ActionDispatch merges them into one parameter hash and lets the query win,
  # so the body token would otherwise be discarded without a word.
  scenario "client attempts to transmit tokens in both the body and the query" do
    page.driver.post "/full_protected_resources?access_token=another-token",
                     { access_token: @token.token }
    response_status_should_be 400
  end

  scenario "client repeats the same token in both the body and the query" do
    page.driver.post "/full_protected_resources?access_token=#{@token.token}",
                     { access_token: @token.token }
    response_status_should_be 400
  end

  scenario "client attempts to request protected resource with expired token" do
    @token.update_attribute :expires_in, -100 # expires token
    with_access_token_header @token.token
    visit "/full_protected_resources"
    response_status_should_be 401
  end

  scenario "client requests protected resource with permanent token" do
    @token.update_attribute :expires_in, nil # never expires
    with_access_token_header @token.token
    visit "/full_protected_resources"
    expect(page.body).to have_content("index")
  end

  scenario "access token with no default scopes" do
    Doorkeeper.configuration.instance_eval do
      @default_scopes = Doorkeeper::OAuth::Scopes.from_array([:public])
      @scopes = default_scopes + optional_scopes
    end
    @token.update_attribute :scopes, "dummy"
    with_access_token_header @token.token
    visit "/full_protected_resources"
    response_status_should_be 403
  end

  scenario "access token with no allowed scopes" do
    @token.update_attribute :scopes, nil
    with_access_token_header @token.token
    visit "/full_protected_resources/1.json"
    response_status_should_be 403
  end

  scenario "access token with one of allowed scopes" do
    @token.update_attribute :scopes, "admin"
    with_access_token_header @token.token
    visit "/full_protected_resources/1.json"
    expect(page.body).to have_content("show")
  end

  scenario "access token with another of allowed scopes" do
    @token.update_attribute :scopes, "write"
    with_access_token_header @token.token
    visit "/full_protected_resources/1.json"
    expect(page.body).to have_content("show")
  end

  scenario "access token with both allowed scopes" do
    @token.update_attribute :scopes, "write admin"
    with_access_token_header @token.token
    visit "/full_protected_resources/1.json"
    expect(page.body).to have_content("show")
  end
end

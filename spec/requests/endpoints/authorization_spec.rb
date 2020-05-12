# frozen_string_literal: true

require "spec_helper"

feature "Authorization endpoint" do
  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    client_exists(name: "MyApp")
  end

  scenario "requires resource owner to be authenticated" do
    visit authorization_endpoint_url(client: @client)
    i_should_see "Sign in"
    i_should_be_on "/"
  end

  context "with authenticated resource owner" do
    background do
      create_resource_owner
      sign_in
    end

    scenario "displays the authorization form" do
      visit authorization_endpoint_url(client: @client)
      i_should_see "Authorize MyApp to use your account?"
    end

    scenario "displays all requested scopes" do
      default_scopes_exist :public
      optional_scopes_exist :write
      visit authorization_endpoint_url(client: @client, scope: "public write")
      i_should_see "Access your public data"
      i_should_see "Update your data"
    end
  end

  context "with a invalid request's param" do
    background do
      create_resource_owner
      sign_in
    end

    context "when missing required param" do
      scenario "displays invalid_request error when missing client" do
        visit authorization_endpoint_url(client: nil, response_type: "code")
        i_should_not_see "Authorize"
        i_should_see_translated_invalid_request_error_message :missing_param, :client_id
      end

      scenario "displays invalid_request error when missing response_type param" do
        visit authorization_endpoint_url(client: @client, response_type: "")
        i_should_not_see "Authorize"
        i_should_see_translated_invalid_request_error_message :missing_param, :response_type
      end

      scenario "displays invalid_request error when missing scope param and authorization server has no default scopes" do
        config_is_set(:default_scopes, [])
        visit authorization_endpoint_url(client: @client, response_type: "code", scope: "")
        i_should_not_see "Authorize"
        i_should_see_translated_invalid_request_error_message :missing_param, :scope
      end
    end

    scenario "displays unsupported_response_type error when using a disabled response type" do
      config_is_set(:grant_flows, ["implicit"])
      visit authorization_endpoint_url(client: @client, response_type: "code")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :unsupported_response_type
    end
  end

  context "when forgery protection enabled" do
    background do
      create_resource_owner
      sign_in
    end

    scenario "raises exception on forged requests" do
      allowing_forgery_protection do
        expect do
          page.driver.post authorization_endpoint_url(
            client_id: @client.uid,
            redirect_uri: @client.redirect_uri,
            response_type: "code",
          )
        end.to raise_error(ActionController::InvalidAuthenticityToken)
      end
    end
  end
end

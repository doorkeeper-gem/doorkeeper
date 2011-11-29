require "spec_helper"

feature "Authorization Request" do
  background do
    resource_owner_is_authenticated
    client_exists
  end

  scenario "resource owner authorize the client" do
    visit authorization_endpoint_url(:client => @client)
    click_on "Authorize"

    # Authorization code was created
    grant = @client.access_grants.first
    grant.should_not be_nil

    i_should_be_on_url redirect_uri_with_code(@client.redirect_uri, grant.token)
  end

  scenario "resource owner with previously authorized client" do
    client_is_authorized(@client, User.last)
    visit authorization_endpoint_url(:client => @client)

    grant = @client.access_grants.first

    # Skips authorization form and redirect with new grant
    i_should_be_on_url redirect_uri_with_code(@client.redirect_uri, grant.token)
  end

  scenario "resource owner deny access to the client" do
    visit authorization_endpoint_url(:client => @client)
    click_on "Deny"
    i_should_be_on_url redirect_uri_with_error(@client.redirect_uri, "access_denied")
  end

  scenario "resource owner recieves an error with invalid client" do
    visit authorization_endpoint_url(:client => @client, :client_id => "invalid")
    i_should_see "An error has occurred"
  end
end

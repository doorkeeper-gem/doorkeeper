require 'spec_helper_integration'

feature "Authorization Request", "with no scopes" do
  background do
    resource_owner_is_authenticated
    client_exists
  end

  scenario "resource owner gets redirected to authentication" do
    visit authorization_endpoint_url(:client => @client)
    i_should_see "Authorize"
  end
end

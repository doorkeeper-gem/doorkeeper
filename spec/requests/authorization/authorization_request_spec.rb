require 'spec_helper_integration'

feature "Authorization Request", "when resource owner is authenticated" do
  background do
    resource_owner_is_authenticated
    client_exists
    scope_exist(:public, :default => true, :description => "Access your public data")
    scope_exist(:write, :description => "Update your data")
  end

  context "with invalid client credentials or redirect_uri for a token response type" do
    after do
      client_should_not_be_authorized(@client)
    end

    [
      [:client_id,     :invalid_client],
      [:redirect_uri,  :invalid_redirect_uri],
    ].each do |error|
      scenario "receives an error for invalid #{error.first}" do
        parameter       = error.first
        translation_key = error.last
        visit authorization_endpoint_url(:client => @client, :response_type => "token", parameter => "invalid")
        i_should_see "An error has occurred"
        i_should_see I18n.translate translation_key, :scope => [:doorkeeper, :errors, :messages]
      end
    end
  end
end

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

require "spec_helper"

feature "Authorization Request", "when resource owner is authenticated" do
  background do
    resource_owner_is_authenticated
    client_exists
    scope_exist(:public, :default => true, :description => "Access your public data")
    scope_exist(:write, :description => "Update your data")
  end

  context "with valid client credentials and parameters" do
    context "display authorization scopes" do
      scenario "default scopes" do
        visit authorization_endpoint_url(:client => @client)
        i_should_see "Access your public data"
        i_should_not_see "Update your data"
      end

      scenario "with scopes specified in param" do
        visit authorization_endpoint_url(:client => @client, :scope => "public write")
        i_should_see "Access your public data"
        i_should_see "Update your data"
      end
    end

    context "with state parameter" do
      scenario "returns the state to client's callback url" do
        visit authorization_endpoint_url(:client => @client, :state => "return-this")
        click_on "Authorize"
        url_should_have_param("state", "return-this")
      end

      scenario "omit the state if no one was specified" do
        visit authorization_endpoint_url(:client => @client)
        click_on "Authorize"
        url_should_not_have_param("state")
      end

      scenario "returns the state if client access was denied" do
        visit authorization_endpoint_url(:client => @client, :state => "return-that")
        click_on "Deny"
        url_should_have_param("state", "return-that")
      end
    end

    scenario "resource owner authorizes the client" do
      visit authorization_endpoint_url(:client => @client)

      click_on "Authorize"
      client_should_be_authorized(@client)

      grant = @client.access_grants.first

      i_should_be_on_client_callback(@client)
      url_should_have_param("code", grant.token)
    end

    scenario "skips authorization for previously authorized clients" do
      client_is_authorized(@client, User.last)
      visit authorization_endpoint_url(:client => @client)

      client_should_be_authorized(@client)

      grant = @client.access_grants.first

      i_should_be_on_client_callback(@client)
      url_should_have_param("code", grant.token)
    end

    scenario "resource owner denies client access" do
      visit authorization_endpoint_url(:client => @client)

      click_on "Deny"
      client_should_not_be_authorized(@client)

      i_should_be_on_client_callback(@client)
      url_should_not_have_param("code")
      url_should_have_param("error", "access_denied")
    end
  end

  context "with invalid client credentials or parameters" do
    after do
      client_should_not_be_authorized(@client)
    end

    [:client_id, :redirect_uri, :response_type, :scope].each do |parameter|
      scenario "recieves an error for invalid #{parameter}" do
        visit authorization_endpoint_url(:client => @client, parameter => "invalid")
        i_should_see "An error has occurred"
      end
    end
  end
end

feature "Authorization Request", "when resource owner is not authenticated" do
  background do
    resource_owner_is_not_authenticated
  end

  scenario "resource owner gets redirected to authentication" do
    visit authorization_endpoint_url(:client_id => "1", :redirect_uri => "r")
    i_should_be_on "/"
  end
end

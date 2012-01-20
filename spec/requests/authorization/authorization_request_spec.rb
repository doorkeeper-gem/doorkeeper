require 'spec_helper_integration'

feature "Authorization Request", "when resource owner is authenticated" do
  background do
    resource_owner_is_authenticated
    client_exists
    scope_exist(:public, :default => true, :description => "Access your public data")
    scope_exist(:write, :description => "Update your data")
  end

  context "with valid client credentials and parameters" do
    context "with state parameter" do
      scenario "returns the state if client access was denied" do
        visit authorization_endpoint_url(:client => @client, :state => "return-that")
        click_on "Deny"
        url_should_have_param("state", "return-that")
      end
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

  context "with invalid client credentials or redirect_uri for a code response type" do
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
        visit authorization_endpoint_url(:client => @client, :response_type => "code", parameter => "invalid")
        i_should_see "An error has occurred"
        i_should_see I18n.translate translation_key, :scope => [:doorkeeper, :errors, :messages]
      end
    end
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

  context "with invalid response type or scope" do
    after do
      client_should_not_be_authorized(@client)
    end

    [
      [:response_type, :unsupported_response_type],
      [:scope,         :invalid_scope]
    ].each do |error|
      scenario "receives an error for invalid #{error.first} and redirects to the code endpoint" do
        parameter       = error.first
        error_type = error.last
        visit authorization_endpoint_url(:client => @client, parameter => "invalid")
        current_params.should_not be_nil
        current_params["error"].should == error_type.to_s
        current_params["error_description"].should == (I18n.translate error_type, :scope => [:doorkeeper, :errors, :messages])
        i_should_be_on_client_callback(@client)
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

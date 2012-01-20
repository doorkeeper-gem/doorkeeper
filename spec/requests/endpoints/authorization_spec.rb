require 'spec_helper_integration'

feature 'Authorization endpoint' do
  background do
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to('/sign_in') }
    client_exists(:name => "MyApp")
  end

  scenario 'requires resource owner to be authenticated' do
    visit authorization_endpoint_url(:client => @client)
    i_should_see "Sign in"
    i_should_be_on "/"
  end

  context 'with authenticated resource owner' do
    background do
      create_resource_owner
      sign_in
    end

    scenario 'displays the authorization form' do
      visit authorization_endpoint_url(:client => @client)
      i_should_see "Authorize MyApp to use your account?"
    end

    scenario 'accepts "code" response type' do
      visit authorization_endpoint_url(:client => @client, :response_type => "code")
      i_should_see "Authorize"
    end

    scenario 'accepts "token" response type' do
      visit authorization_endpoint_url(:client => @client, :response_type => "token")
      i_should_see "Authorize"
    end
  end

  context 'with scopes' do
    background do
      create_resource_owner
      sign_in
      scope_exist :public, :default => true, :description => "Access your public data"
      scope_exist :write,  :description => "Update your data"
    end

    scenario "displays default scopes when no scope was requested" do
      visit authorization_endpoint_url(:client => @client)
      i_should_see "Access your public data"
      i_should_not_see "Update your data"
    end

    scenario "displays all requested scopes" do
      visit authorization_endpoint_url(:client => @client, :scope => "public write")
      i_should_see "Access your public data"
      i_should_see "Update your data"
    end

    scenario "does not display default scope if it was not requested" do
      visit authorization_endpoint_url(:client => @client, :scope => "write")
      i_should_not_see "Access your public data"
      i_should_see "Update your data"
    end
  end
end

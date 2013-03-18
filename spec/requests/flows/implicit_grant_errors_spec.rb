require 'spec_helper_integration'

feature 'Implicit Grant Flow Errors' do
  background do
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to('/sign_in') }
    client_exists
    create_resource_owner
    sign_in
  end

  after do
    access_token_should_not_exist
  end

  [
    [:client_id,     :invalid_client],
  ].each do |error|
    scenario "displays #{error.last.inspect} error for invalid #{error.first.inspect}" do
      visit authorization_endpoint_url(:client => @client, error.first => "invalid", :response_type => "token")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message error.last
    end

    scenario "displays #{error.last.inspect} error when #{error.first.inspect} is missing" do
      visit authorization_endpoint_url(:client => @client, error.first => "", :response_type => "token")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message error.last
    end
  end

  scenario "displays :invalid_redirect_uri error when :redirect_uri does not match application" do
    visit authorization_endpoint_url(:client => @client, :redirect_uri => "invalid",  :response_type => "token")
    i_should_not_see "Authorize"
    i_should_see_translated_error_message :invalid_redirect_uri
  end

  scenario "displays :invalid_redirect_uri error when :redirect_uri is missing from client and request" do
    @client.redirect_uri = nil
    @client.save
    visit authorization_endpoint_url(:client => @client, :redirect_uri => "invalid",  :response_type => "token")
    i_should_not_see "Authorize"
    i_should_see_translated_error_message :invalid_redirect_uri
  end
end

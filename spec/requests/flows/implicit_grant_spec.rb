require 'spec_helper_integration'

feature 'Implicit Grant Flow' do
  background do
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to('/sign_in') }
    client_exists
    create_resource_owner
    sign_in
  end

  scenario 'resource owner authorizes the client' do
    visit authorization_endpoint_url(client: @client, response_type: 'token')
    click_on 'Authorize'

    access_token_should_exist_for @client, @resource_owner

    i_should_be_on_client_callback @client
  end
end

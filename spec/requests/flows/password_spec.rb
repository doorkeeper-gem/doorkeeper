# coding: utf-8

# TODO: this flow should be configurable (letting Doorkeeper users decide if
# they want to make it available)

require 'spec_helper_integration'

feature 'Resource Owner Password Credentials Flow' do
  background do
    config_is_set(:resource_owner_from_credentials) { User.authenticate! params[:username], params[:password] }
    client_exists
    create_resource_owner
  end

  context 'with valid user credentials' do
    scenario "should issue new token" do
      expect {
        post password_token_endpoint_url(:client => @client, :resource_owner => @resource_owner)
      }.to change { Doorkeeper::AccessToken.count }.by(1)

      token = Doorkeeper::AccessToken.first

      should_have_json 'access_token',  token.token
    end

    scenario "should issue a refresh token if enabled" do
      config_is_set(:refresh_token_enabled, true)

      post password_token_endpoint_url(:client => @client, :resource_owner => @resource_owner)

      token = Doorkeeper::AccessToken.first

      should_have_json 'refresh_token',  token.refresh_token
    end

    scenario 'should return the same token if it is still accessible' do
      client_is_authorized(@client, @resource_owner)

      post password_token_endpoint_url(:client => @client, :resource_owner => @resource_owner)

      Doorkeeper::AccessToken.count.should be(1)

      should_have_json 'access_token', Doorkeeper::AccessToken.first.token
    end
  end

  context "with invalid user credentials" do
    scenario "should not issue new token with bad password" do
      expect {
        post password_token_endpoint_url( :client => @client,
                                          :resource_owner_username => @resource_owner.name,
                                          :resource_owner_password => 'wrongpassword')
      }.to_not change { Doorkeeper::AccessToken.count }
    end

    scenario "should not issue new token without credentials" do
      expect {
        post password_token_endpoint_url( :client => @client)
      }.to_not change { Doorkeeper::AccessToken.count }
    end
  end
end

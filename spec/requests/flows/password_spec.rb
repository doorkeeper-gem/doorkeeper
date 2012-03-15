# coding: utf-8

# ========================================
# Resource Owner Password Credentials flow
# ========================================
#
# In this flow, a token is requested in exchange for the resource owner
# credentials (username and password):
#
# http://tools.ietf.org/html/draft-ietf-oauth-v2-25#page-9
# http://tools.ietf.org/html/draft-ietf-oauth-v2-25#page-34
#
# For instance, using the oauth2 ruby gem, we would request it like this:
#
#   client = OAuth2::Client.new('the_client_id', 'the_client_secret',
#                               :site => "http://example.com")
#   access_token = client.password.get_token('user@example.com', 'sekret')
#
# That will make a POST request to the OAuth providers "/oauth/token" endpoint,
# with the params:
#
#   "grant_type"    => "password"
#   "username"      => "user@example.com"
#   "password"      => "sekret"
#   "client_id"     => "the_client_id"
#   "client_secret" => "the_client_secret"
#
# The Rails app will need to implement user authentication based on username and
# password, and Doorkeeper will have to be configured to use this authentication
# to get the resource owner from the credentials
#
# TODO: this flow should be configurable (letting Doorkeeper users decide if
# they want to make it available)

require 'spec_helper_integration'

feature 'Resource Owner Password Credentials Flow' do
  background do
    config_is_set(:resource_owner_from_credentials) { owner = User.find_by_name(params[:username])
                                                      owner.authenticate(params[:password]) if owner }
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
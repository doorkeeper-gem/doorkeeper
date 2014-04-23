# coding: utf-8

require 'spec_helper_integration'

feature 'Resource Owner Assertion Flow inproperly set up' do
  background do
    client_exists
    create_resource_owner
  end

  context 'with valid user assertion' do
    scenario "should not issue new token" do
      expect {
        post assertion_endpoint_url(:client => @client, :resource_owner => @resource_owner)
      }.to_not change { Doorkeeper::AccessToken.count }
    end
  end
end

feature 'Resource Owner Assertion Flow' do
  background do
    config_is_set(:resource_owner_from_assertion) { User.where(:assertion => params[:assertion]).first }
    client_exists
    create_resource_owner
  end

  context 'with valid user assertion' do
    scenario "should issue new token" do
      expect {
        post assertion_endpoint_url(:client => @client, :resource_owner => @resource_owner)
      }.to change { Doorkeeper::AccessToken.count }.by(1)

      token = Doorkeeper::AccessToken.first

      should_have_json 'access_token',  token.token
    end

    scenario "should issue a refresh token if enabled" do
      config_is_set(:refresh_token_enabled, true)

      post assertion_endpoint_url(:client => @client, :resource_owner => @resource_owner)

      token = Doorkeeper::AccessToken.first

      should_have_json 'refresh_token',  token.refresh_token
    end

  end

  context "with invalid user assertion" do
    scenario "should not issue new token with bad assertion" do
      expect {
        post assertion_endpoint_url( :client => @client, :assertion => 'i_dont_exist' )
      }.to_not change { Doorkeeper::AccessToken.count }
    end

    scenario "should not issue new token without assertion" do
      expect {
        post assertion_endpoint_url( :client => @client )
      }.to_not change { Doorkeeper::AccessToken.count }
    end

  end
end

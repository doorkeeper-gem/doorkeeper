require 'spec_helper_integration'

feature 'ActionController::Metal API' do
  background do
    @client   = FactoryGirl.create(:application)
    @resource = User.create!(name: 'Joe', password: 'sekret')
    @token    = client_is_authorized(@client, @resource)
  end

  scenario 'client requests protected resource with valid token' do
    get "/metal.json?access_token=#{@token.token}"
    should_have_json 'ok', true
  end
end

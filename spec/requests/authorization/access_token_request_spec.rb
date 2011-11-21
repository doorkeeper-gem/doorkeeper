require "spec_helper"

feature "Access token request" do
  let(:client) { Factory(:application) }
  let(:code)   { Factory(:access_grant) }

  scenario "requesting with valid grant code" do
    post "/oauth/token?code=#{code.token}&client_id=#{client.uid}&client_secret=#{client.secret}"
    body = JSON.parse(response.body)
    body['access_token'].should =~ /\w+/
    body['token_type'].should == "bearer"
  end
end

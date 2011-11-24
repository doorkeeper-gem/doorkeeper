require "spec_helper"

feature "Access token request" do
  let(:client) { Factory(:application) }
  let(:code)   { Factory(:access_grant, :application => client) }

  scenario "requesting with valid grant code" do
    post "/oauth/token?code=#{code.token}&client_id=#{client.uid}&client_secret=#{client.secret}&redirect_uri=#{client.redirect_uri}&grant_type=authorization_code"

    json.should_not have_key('error')

    # Return the access token response
    json['access_token'].should =~ /\w+/
    json['token_type'].should == "bearer"
  end

  scenario "requesting with invalid grant code" do
    post "/oauth/token?code=invalid&client_id=#{client.uid}&client_secret=#{client.secret}&redirect_uri=#{client.redirect_uri}&grant_type=authorization_code"

    json.should_not have_key('access_token')

    json['error'].should == 'invalid_grant'
  end

  def json
    JSON.parse(response.body)
  end
end

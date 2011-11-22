require "spec_helper"

feature "Authorization Request" do
  let(:client) { Factory(:application) }

  before do
    Doorkeeper.stub(:authenticate_resource_owner => proc do User.create! end)
  end

  scenario "requesting with valid client" do
    visit "/oauth/authorize?client_id=#{client.uid}&redirect_uri=#{client.redirect_uri}&response_type=code"
    click_on "Authorize"

    # Authorization code was created
    grant = client.access_grants.first
    grant.should_not be_nil

    i_should_be_on_url redirect_uri_with_code(client.redirect_uri, grant.token)
  end

  scenario "requesting with invalid valid client_id" do
    visit "/oauth/authorize?client_id=invalid&redirect_uri=#{client.redirect_uri}&response_type=code"
    i_should_see "An error has occurred"
  end

  def redirect_uri_with_code(uri, code)
    uri = URI.parse(uri)
    uri.query = "code=#{code}"
    uri.to_s
  end
end

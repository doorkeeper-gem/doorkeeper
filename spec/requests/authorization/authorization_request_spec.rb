require "spec_helper"

feature "Authorization Request" do
  let(:client) { Factory(:application) }

  scenario "requesting with valid app" do
    pending
    visit "/oauth/authorize?client_id=#{client.uid}&response_type=code"
    click_on "Authorize"
  end
end

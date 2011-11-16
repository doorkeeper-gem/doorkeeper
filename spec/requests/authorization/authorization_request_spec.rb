require "spec_helper"

feature "Authorization Request" do
  background do
    application = double(:application, :uid => "uniqueid")
  end

  scenario "requesting with valid app" do
    visit '/oauth/authorize?client_id=uniqueid'
  end
end

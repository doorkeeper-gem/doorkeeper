require 'spec_helper'

feature 'Adding applications' do
  context 'in application form' do
    background do
      visit '/oauth/applications/new'
    end

    scenario 'adding a valid app' do
      fill_in 'Name', :with => 'My Application'
      fill_in 'Redirect uri', :with => 'http://example.com'
      click_button 'Submit'
      i_should_see 'Application created'
      i_should_see 'My Application'
    end

    scenario 'adding invalid app' do
      click_button 'Submit'
      i_should_see 'Whoops! Check your form for possible errors'
    end
  end
end

feature 'Listing applications' do
  background do
    Factory :application, :name => 'Oauth Dude'
    Factory :application, :name => 'Awesome App'
  end

  scenario 'application list' do
    visit '/oauth/applications'
    i_should_see 'Awesome App'
    i_should_see 'Oauth Dude'
  end
end

feature 'Show application' do
  let :app do
    Factory :application, :name => 'Just another oauth app'
  end

  scenario 'visiting application page' do
    visit "/oauth/applications/#{app.id}"
    i_should_see 'Just another oauth app'
  end
end

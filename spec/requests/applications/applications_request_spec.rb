require 'spec_helper'

feature 'Adding applications' do
  context 'in application form' do
    background do
      i_am_logged_in
      visit '/oauth/applications/new'
    end

    scenario 'adding a valid app' do
      fill_in 'doorkeeper_application[name]', with: 'My Application'
      fill_in 'doorkeeper_application[redirect_uri]',
              with: 'https://example.com'

      click_button 'Submit'
      i_should_see 'Application created'
      i_should_see 'My Application'
    end

    scenario 'adding invalid app' do
      click_button 'Submit'
      i_should_see 'Whoops! Check your form for possible errors'
    end

    scenario "adding app ignoring bad scope" do
      config_is_set("enforce_configured_scopes", false)

      fill_in "doorkeeper_application[name]", with: "My Application"
      fill_in "doorkeeper_application[redirect_uri]",
              with: "https://example.com"
      fill_in "doorkeeper_application[scopes]", with: "blahblah"

      click_button "Submit"
      i_should_see "Application created"
      i_should_see "My Application"
    end

    scenario "adding app validating bad scope" do
      config_is_set("enforce_configured_scopes", true)

      fill_in "doorkeeper_application[name]", with: "My Application"
      fill_in "doorkeeper_application[redirect_uri]",
              with: "https://example.com"
      fill_in "doorkeeper_application[scopes]", with: "blahblah"

      click_button "Submit"
      i_should_see "Whoops! Check your form for possible errors"
    end

    scenario "adding app validating scope, blank scope is accepted" do
      config_is_set("enforce_configured_scopes", true)

      fill_in "doorkeeper_application[name]", with: "My Application"
      fill_in "doorkeeper_application[redirect_uri]",
              with: "https://example.com"
      fill_in "doorkeeper_application[scopes]", with: ""

      click_button "Submit"
      i_should_see "Application created"
      i_should_see "My Application"
    end

    scenario "adding app validating scope, multiple scopes configured" do
      config_is_set("enforce_configured_scopes", true)
      scopes = Doorkeeper::OAuth::Scopes.from_array(%w(read write admin))
      config_is_set("optional_scopes", scopes)

      fill_in "doorkeeper_application[name]", with: "My Application"
      fill_in "doorkeeper_application[redirect_uri]",
              with: "https://example.com"
      fill_in "doorkeeper_application[scopes]", with: "read write"

      click_button "Submit"
      i_should_see "Application created"
      i_should_see "My Application"
    end

    scenario "adding app validating scope, bad scope with multiple scopes configured" do
      config_is_set("enforce_configured_scopes", true)
      scopes = Doorkeeper::OAuth::Scopes.from_array(%w(read write admin))
      config_is_set("optional_scopes", scopes)

      fill_in "doorkeeper_application[name]", with: "My Application"
      fill_in "doorkeeper_application[redirect_uri]",
              with: "https://example.com"
      fill_in "doorkeeper_application[scopes]", with: "read blah"

      click_button "Submit"
      i_should_see "Whoops! Check your form for possible errors"
      i_should_see Regexp.new(
        I18n.t('activerecord.errors.models.doorkeeper/application.attributes.scopes.not_match_configured'),
        true
      )
    end
  end
end

feature 'Listing applications' do
  background do
    i_am_logged_in

    FactoryBot.create :application, name: 'Oauth Dude'
    FactoryBot.create :application, name: 'Awesome App'
  end

  scenario 'application list' do
    visit '/oauth/applications'

    i_should_see 'Awesome App'
    i_should_see 'Oauth Dude'
  end
end

feature 'Renders assets' do
  scenario 'admin stylesheets' do
    visit '/assets/doorkeeper/admin/application.css'

    i_should_see 'Bootstrap'
    i_should_see '.doorkeeper-admin'
  end

  scenario 'application stylesheets' do
    visit '/assets/doorkeeper/application.css'

    i_should_see 'Bootstrap'
    i_should_see '#oauth-permissions'
    i_should_see '#container'
  end
end

feature 'Show application' do
  given :app do
    i_am_logged_in

    FactoryBot.create :application, name: 'Just another oauth app'
  end

  scenario 'visiting application page' do
    visit "/oauth/applications/#{app.id}"

    i_should_see 'Just another oauth app'
  end
end

feature 'Edit application' do
  let :app do
    FactoryBot.create :application, name: 'OMG my app'
  end

  background do
    i_am_logged_in

    visit "/oauth/applications/#{app.id}/edit"
  end

  scenario 'updating a valid app' do
    fill_in 'doorkeeper_application[name]', with: 'Serious app'
    click_button 'Submit'

    i_should_see 'Application updated'
    i_should_see 'Serious app'
    i_should_not_see 'OMG my app'
  end

  scenario 'updating an invalid app' do
    fill_in 'doorkeeper_application[name]', with: ''
    click_button 'Submit'

    i_should_see 'Whoops! Check your form for possible errors'
  end
end

feature 'Remove application' do
  background do
    i_am_logged_in

    @app = FactoryBot.create :application
  end

  scenario 'deleting an application from list' do
    visit '/oauth/applications'

    i_should_see @app.name

    within(:css, "tr#application_#{@app.id}") do
      click_button 'Destroy'
    end

    i_should_see 'Application deleted'
    i_should_not_see @app.name
  end

  scenario 'deleting an application from show' do
    visit "/oauth/applications/#{@app.id}"
    click_button 'Destroy'

    i_should_see 'Application deleted'
  end
end

context 'when admin authenticator block is default' do
  let(:app) { FactoryBot.create :application, name: 'app' }

  feature 'application list' do
    scenario 'fails with forbidden' do
      visit '/oauth/applications'

      should_have_status 403
    end
  end

  feature 'adding an app' do
    scenario 'fails with forbidden' do
      visit '/oauth/applications/new'

      should_have_status 403
    end
  end

  feature 'editing an app' do
    scenario 'fails with forbidden' do
      visit "/oauth/applications/#{app.id}/edit"

      should_have_status 403
    end
  end
end

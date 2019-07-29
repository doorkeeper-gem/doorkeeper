# frozen_string_literal: true

require "spec_helper"

feature "Authorization Code Flow" do
  let(:resource_owner) { FactoryBot.create(:doorkeeper_testing_user, name: "Joe", password: "sekret") }
  let(:application) { FactoryBot.create(:application, owner_id: resource_owner.id) }
  let(:access_grant) { FactoryBot.create(:access_grant, user_code: "1234", application: application) }

  unless ENV["WITHOUT_DEVICE_CODE"]
    background do
      access_grant
      config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
      sign_in
    end

    scenario "resource owner visits page to authorize the device" do
      visit oauth_device_index_url

      i_should_see "Authorize your device"
      i_should_see "User Code"
      i_should_see "Submit"
    end

    scenario "resource owner visits page with user code" do
      visit oauth_device_url(access_grant.user_code)

      i_should_see "You authorize the device #{application.name} with your user code, to access your account."
    end

    context "valid requests" do
      scenario "resource owner verifies device" do
        visit oauth_device_url(access_grant.user_code)

        click_on "Authorize"
        i_should_see "Device authorized"
      end

      scenario "resource owner denies device" do
        visit oauth_device_url(access_grant.user_code)

        click_on "Deny"
        i_should_see "Device denied"
      end
    end

    context "invalid request" do
      scenario "invalid user code" do
        visit oauth_device_url("invalid user code")

        i_should_see_translated_error_message("user_code.unknown")
      end

      scenario "expired user code" do
        access_grant.update expires_in: -100
        visit oauth_device_url(access_grant.user_code)

        i_should_see_translated_error_message("user_code.expired")
      end

      scenario "revoked user code" do
        access_grant.update revoked_at: Time.now
        visit oauth_device_url(access_grant.user_code)

        i_should_see_translated_error_message("user_code.revoked")
      end
    end
  end
end

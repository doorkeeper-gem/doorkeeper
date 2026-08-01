# frozen_string_literal: true

require "spec_helper"

feature "Authorized applications" do
  background do
    @user   = User.create!(name: "Joe", password: "sekret")
    @client = client_exists(name: "Amazing Client App")
    resource_owner_is_authenticated @user
    client_is_authorized @client, @user
  end

  scenario "display user's authorized applications" do
    visit "/oauth/authorized_applications"
    i_should_see "Amazing Client App"
  end

  scenario "do not display other user's authorized applications" do
    client = client_exists(name: "Another Client App")
    client_is_authorized client, User.create!(name: "Joe", password: "sekret")
    visit "/oauth/authorized_applications"
    i_should_not_see "Another Client App"
  end

  # Draft Section 8.5: the client's own name is unverified, so the host that
  # served its document is shown here as well as on the consent screen, which
  # is where the user sees the two together again.
  scenario "display the client_id host of a metadata document client" do
    config_is_set(:client_id_metadata_documents, true)
    document_client = FactoryBot.create(
      :application,
      name: "Example App",
      uid: "https://client.example.com/oauth-client",
      client_id_metadata_materialized_at: Time.now.utc,
    )
    client_is_authorized document_client, @user

    visit "/oauth/authorized_applications"

    i_should_see "Example App"
    i_should_see "client.example.com"
  end

  scenario "user revoke access to application" do
    visit "/oauth/authorized_applications"
    i_should_see "Amazing Client App"
    click_on "Revoke"
    i_should_see "Application revoked"
    i_should_not_see "Amazing Client App"
  end
end

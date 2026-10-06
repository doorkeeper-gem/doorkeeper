# frozen_string_literal: true

require "spec_helper"

# force_pkce enabled without the migration the doorkeeper:pkce generator
# creates: there is nowhere to store a code_challenge, so the token endpoint
# would have nothing to check a code_verifier against and accept any value.
# Both endpoints refuse the authorization code flow with server_error instead.
feature "force_pkce when the PKCE columns are missing" do
  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    client_exists
    create_resource_owner
    sign_in

    allow(Doorkeeper.config).to receive(:force_pkce?).and_return(true)
    allow(Doorkeeper.config.access_grant_model).to receive(:pkce_supported?).and_return(false)
    allow(Rails.logger).to receive(:error)
  end

  scenario "the authorization endpoint answers server_error without issuing a code" do
    expect(Rails.logger).to receive(:error).with(/rails generate doorkeeper:pkce/)

    visit authorization_endpoint_url(
      client: @client,
      code_challenge: "a45a9fea-0676-477e-95b1-a40f72ac3cfb",
      code_challenge_method: "plain",
    )

    access_grant_should_not_exist
    i_should_not_see "Authorize"
    i_should_see_translated_error_message(:server_error)
  end

  scenario "the token endpoint answers server_error for a code issued without a stored challenge" do
    authorization_code_exists(
      application: @client,
      resource_owner_id: @resource_owner.id,
      resource_owner_type: @resource_owner.class.name,
    )

    expect(Rails.logger).to receive(:error).with(/rails generate doorkeeper:pkce/)

    expect do
      page.driver.post token_endpoint_url, token_endpoint_params(
        code: @authorization.token, client: @client, code_verifier: "any-verifier-at-all",
      )
    end.not_to(change { Doorkeeper::AccessToken.count })

    expect(page.driver.response.status).to eq(400)
    expect(json_response["error"]).to eq("server_error")
    expect(json_response["error_description"]).to eq(translated_error_message(:server_error))
    expect(json_response["error_description"]).not_to include("doorkeeper:pkce")
  end
end

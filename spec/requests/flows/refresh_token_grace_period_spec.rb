# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Refresh token grace period" do
  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_refresh_token
    end

    client_exists
  end

  let(:resource_owner) { FactoryBot.create(:resource_owner) }
  let(:token) do
    FactoryBot.create(:access_token, application: @client, resource_owner_id: resource_owner.id,
                                     resource_owner_type: resource_owner.class.name, use_refresh_token: true,)
  end

  def refresh(refresh_token)
    post refresh_token_endpoint_url, params: refresh_token_endpoint_params(client: @client, refresh_token: refresh_token)
    json_response
  end

  it "keeps a replaced refresh token usable while the token that replaced it is unused" do
    refresh(token.refresh_token)
    expect(response).to have_http_status(:ok)

    refresh(token.refresh_token)
    expect(response).to have_http_status(:ok)
  end

  # The client refreshes twice without its access tokens passing through
  # Doorkeeper's authentication, e.g. a resource server that checks tokens
  # with AccessToken.by_token or introspection.
  it "ends for a refresh token once the token that replaced it is refreshed" do
    second = refresh(token.refresh_token)
    refresh(second.fetch("refresh_token"))
    expect(response).to have_http_status(:ok)

    refresh(token.refresh_token)
    expect(response).to have_http_status(:bad_request)
  end
end

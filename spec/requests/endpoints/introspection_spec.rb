# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Introspection endpoint" do
  before do
    Doorkeeper.configure { orm DOORKEEPER_ORM }
  end

  let(:client) { FactoryBot.create(:application) }
  let(:access_token) { FactoryBot.create(:access_token, application: client) }

  it "authenticates the client with credentials in the request body (client_secret_post)" do
    post introspection_endpoint_url,
         params: {
           client_id: client.uid,
           client_secret: client.secret,
           token: access_token.token,
         }

    expect(response).to be_successful
    expect(json_response).to include("active" => true)
  end

  it "authenticates the client with HTTP Basic credentials (client_secret_basic)" do
    post introspection_endpoint_url,
         params: { token: access_token.token },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(client) }

    expect(response).to be_successful
    expect(json_response).to include("active" => true)
  end

  context "when authenticating the client with an access token" do
    let(:authorized_token) { FactoryBot.create(:access_token, application: client) }

    it "authorizes the request" do
      post introspection_endpoint_url,
           params: { token: access_token.token },
           headers: { "HTTP_AUTHORIZATION" => "Bearer #{authorized_token.token}" }

      expect(response).to be_successful
      expect(json_response).to include("active" => true)
    end

    context "when the authorized token uses dpop" do
      before { authorized_token.update!(dpop_jkt: "jkt_abc") }

      it "rejects the request" do
        post introspection_endpoint_url,
             params: { token: access_token.token },
             headers: { "HTTP_AUTHORIZATION" => "Bearer #{authorized_token.token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response).to include("error" => "invalid_token")
        expect(json_response).not_to include("active")
      end
    end
  end

  it "does not read client credentials from the query string (RFC 6749 §2.3.1)" do
    query = build_query(client_id: client.uid, client_secret: client.secret)

    post "#{introspection_endpoint_url}?#{query}", params: { token: access_token.token }

    expect(response).to have_http_status(:bad_request)
    expect(json_response).to include("error" => "invalid_request")
    expect(json_response).not_to include("active")
  end

  # Regression spec for doorkeeper#1858: a refresh token bound to an expired
  # access token is still accepted by the token endpoint, so introspecting it
  # must report active: true.
  context "when introspecting a refresh token bound to an expired access token" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
      end
    end

    let(:access_token) do
      FactoryBot.create(:access_token, application: client, use_refresh_token: true).tap do |token|
        token.update!(created_at: token.created_at - token.expires_in - 1)
      end
    end

    it "reports the refresh token as active and the token endpoint accepts it" do
      post introspection_endpoint_url,
           params: { token: access_token.refresh_token },
           headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(client) }

      expect(response).to be_successful
      expect(json_response).to include("active" => true)
      expect(json_response).not_to include("exp", "token_type")

      post refresh_token_endpoint_url,
           params: refresh_token_endpoint_params(client: client, refresh_token: access_token.refresh_token)

      expect(response).to be_successful
      expect(json_response).to include("access_token", "refresh_token")
    end
  end

  # Regression specs for https://github.com/doorkeeper-gem/doorkeeper/issues/1759
  #
  # With refresh_token_revoked_on_use? the previous refresh token is revoked
  # when the rotated access token is first *used* — i.e. when it authenticates
  # a protected resource request (Doorkeeper::OAuth::Token.authenticate).
  # Introspection (RFC 7662) reports token state; it is not token use, so it
  # must not finalize the rotation. Both sides of the asymmetry are pinned.
  context "when the introspected token still references a previous refresh token" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
      end
    end

    let!(:old_token) do
      FactoryBot.create(:access_token, application: client, use_refresh_token: true)
    end

    let!(:rotated_token) do
      FactoryBot.create(
        :access_token,
        application: client,
        use_refresh_token: true,
        previous_refresh_token: old_token.refresh_token,
      )
    end

    it "does not revoke the previous refresh token" do
      post introspection_endpoint_url,
           params: {
             client_id: client.uid,
             client_secret: client.secret,
             token: rotated_token.token,
           }

      expect(response).to be_successful
      expect(json_response).to include("active" => true)
      expect(old_token.reload).not_to be_revoked
      expect(rotated_token.reload.previous_refresh_token).to eq(old_token.refresh_token)
    end

    it "revokes the previous refresh token when the token authenticates a protected resource request" do
      get "/full_protected_resources",
          headers: { "HTTP_AUTHORIZATION" => "Bearer #{rotated_token.token}" }

      expect(response).to be_successful
      expect(old_token.reload).to be_revoked
      expect(rotated_token.reload.previous_refresh_token).to be_blank
    end
  end

  it "rejects the request when it uses more than one client authentication method (RFC 6749 §2.3)" do
    post introspection_endpoint_url,
         params: {
           client_id: client.uid,
           client_secret: client.secret,
           token: access_token.token,
         },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(client) }

    expect(response).to have_http_status(:bad_request)
    expect(json_response).to include(
      "error" => "invalid_request",
      "error_description" => translated_invalid_request_error_message(:multiple_client_auth_methods, nil),
    )
    expect(json_response).not_to include("active")
  end
end

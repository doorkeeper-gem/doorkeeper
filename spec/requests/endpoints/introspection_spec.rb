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

  it "does not read client credentials from the query string (RFC 6749 §2.3.1)" do
    query = build_query(client_id: client.uid, client_secret: client.secret)

    post "#{introspection_endpoint_url}?#{query}", params: { token: access_token.token }

    expect(response).to have_http_status(:bad_request)
    expect(json_response).to include("error" => "invalid_request")
    expect(json_response).not_to include("active")
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

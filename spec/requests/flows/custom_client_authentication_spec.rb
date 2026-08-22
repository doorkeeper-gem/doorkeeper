# frozen_string_literal: true

# End-to-end coverage for the client authentication registry [#1840],
# mirroring the README "Custom Client Authentication Methods" example.

require "spec_helper"

module PartnerHeadersExample
  # Reads the client credentials a partner integration sends in its own
  # headers instead of the transports RFC 6749 §2.3 defines.
  class Authentication
    def self.matches_request?(request)
      request.get_header("HTTP_X_CLIENT_ID").present? &&
        request.get_header("HTTP_X_CLIENT_SECRET").present?
    end

    def self.authenticate(request)
      Doorkeeper::ClientAuthentication::Credentials.new(
        request.get_header("HTTP_X_CLIENT_ID"),
        request.get_header("HTTP_X_CLIENT_SECRET"),
      )
    end
  end
end

RSpec.describe "Custom client authentication method (README example)" do
  let(:client) { FactoryBot.create :application }

  before do
    Doorkeeper::ClientAuthentication.register(
      :partner_headers,
      PartnerHeadersExample::Authentication,
    )

    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      grant_flows %w[client_credentials]
      client_authentication %i[client_secret_basic client_secret_post partner_headers none]
    end
  end

  after do
    Doorkeeper::ClientAuthentication.registered_methods.delete(:partner_headers)
  end

  def partner_headers(uid, secret)
    { "HTTP_X_CLIENT_ID" => uid, "HTTP_X_CLIENT_SECRET" => secret }
  end

  def basic_auth(uid, secret)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(uid, secret)
    { "HTTP_AUTHORIZATION" => credentials }
  end

  it "authenticates a client whose credentials arrive in the custom headers" do
    post token_endpoint_url,
         params: { grant_type: "client_credentials" },
         headers: partner_headers(client.uid, client.secret)

    expect(response.status).to eq(200)
    expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
  end

  it "rejects a wrong secret with invalid_client" do
    post token_endpoint_url,
         params: { grant_type: "client_credentials" },
         headers: partner_headers(client.uid, "wrong-secret")

    expect(response.status).to eq(401)
    expect(json_response).to include("error" => "invalid_client")
  end

  it "leaves the built-in methods working" do
    post token_endpoint_url,
         params: { grant_type: "client_credentials" },
         headers: basic_auth(client.uid, client.secret)

    expect(response.status).to eq(200)
  end

  # RFC 6749 §2.3: a client must not use more than one authentication method in
  # a single request. The check runs across the whole registry, so it fires for
  # a method that is registered but not enabled too — `client_secret_basic` is
  # deliberately left out of `client_authentication` here, which is what makes
  # this example fail if the check were ever narrowed to the enabled methods.
  it "rejects a request that also carries a registered but disabled method's credentials" do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      grant_flows %w[client_credentials]
      client_authentication %i[partner_headers none]
    end

    post token_endpoint_url,
         params: { grant_type: "client_credentials" },
         headers: partner_headers(client.uid, client.secret)
           .merge(basic_auth(client.uid, client.secret))

    expect(response.status).to eq(400)
    expect(json_response).to include("error" => "invalid_request")
  end

  it "advertises the registered method in the server metadata" do
    get "/.well-known/oauth-authorization-server"

    expect(json_response["token_endpoint_auth_methods_supported"]).to include("partner_headers")
  end

  # A strategy that declares the IANA name it implements is advertised under
  # that name, not under the key the host application registered it with: the
  # advertised value is what a client writes into a request, or into a
  # metadata document's token_endpoint_auth_method, and only the declared name
  # is matched there.
  it "advertises the IANA name a strategy declares rather than its registration key" do
    strategy = Class.new(PartnerHeadersExample::Authentication) do
      def self.auth_method_name = "tls_client_auth"
    end
    Doorkeeper::ClientAuthentication.register(:corporate_mtls, strategy)
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      grant_flows %w[client_credentials]
      client_authentication %i[corporate_mtls none]
    end

    get "/.well-known/oauth-authorization-server"

    expect(json_response["token_endpoint_auth_methods_supported"]).to eq(%w[tls_client_auth none])
  ensure
    Doorkeeper::ClientAuthentication.registered_methods.delete(:corporate_mtls)
  end
end

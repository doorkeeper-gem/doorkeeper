# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Client secret rotation" do
  include_context "with client secret rotation"

  let(:client) { FactoryBot.create(:application) }

  # Read before rotating: under Plain, `plaintext_secret` reads the column the rotation overwrites.
  let!(:old_secret) { client.plaintext_secret }

  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      enable_secret_rotation
      grant_flows %w[client_credentials]
    end
  end

  def request_token(params)
    post token_endpoint_url, params: { grant_type: "client_credentials" }.merge(params)
  end

  def request_token_with_basic_auth(secret)
    post token_endpoint_url,
         params: { grant_type: "client_credentials" },
         headers: {
           "HTTP_AUTHORIZATION" =>
             ActionController::HttpAuthentication::Basic.encode_credentials(client.uid, secret),
         }
  end

  context "when the grace period is open" do
    let!(:new_secret) do
      retain_current_secret(client)
      client.plaintext_secret
    end

    it "accepts the superseded secret over client_secret_basic" do
      request_token_with_basic_auth(old_secret)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
    end

    it "accepts the superseded secret over client_secret_post" do
      request_token(client_id: client.uid, client_secret: old_secret)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
    end

    it "accepts the new secret" do
      request_token_with_basic_auth(new_secret)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
    end

    it "still rejects an unrelated secret" do
      request_token_with_basic_auth("nope")

      expect(response).to have_http_status(:unauthorized)
      expect(json_response).to include("error" => "invalid_client")
    end
  end

  context "when the option is left disabled" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        grant_flows %w[client_credentials]
      end
    end

    it "rejects a secret sitting in the old_secret column" do
      client.update_column(:old_secret, "left behind")

      request_token_with_basic_auth("left behind")

      expect(response).to have_http_status(:unauthorized)
      expect(json_response).to include("error" => "invalid_client")
    end

    it "still accepts the current secret" do
      request_token_with_basic_auth(old_secret)

      expect(response).to have_http_status(:ok)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Refresh Token Flow" do
  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_refresh_token
    end

    client_exists
  end

  let(:resource_owner) { FactoryBot.create(:resource_owner) }

  describe "issuing a refresh token" do
    before do
      authorization_code_exists application: @client,
                                resource_owner_id: resource_owner.id,
                                resource_owner_type: resource_owner.class.name
    end

    it "client gets the refresh token and refreshes it" do
      post token_endpoint_url(code: @authorization.token, client: @client)

      token = Doorkeeper::AccessToken.first

      expect(json_response).to include(
        "access_token" => token.token,
        "refresh_token" => token.refresh_token,
      )

      expect(@authorization.reload).to be_revoked

      post refresh_token_endpoint_url(client: @client, refresh_token: token.refresh_token)

      new_token = Doorkeeper::AccessToken.last
      expect(json_response).to include(
        "access_token" => new_token.token,
        "refresh_token" => new_token.refresh_token,
      )

      expect(token.token).not_to eq(new_token.token)
      expect(token.refresh_token).not_to eq(new_token.refresh_token)
    end
  end

  describe "refreshing the token" do
    before do
      @token = FactoryBot.create(
        :access_token,
        application: @client,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
    end

    context "when reuse_access_token is used" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          reuse_access_token
          use_refresh_token
        end
      end

      it "uses the last created token when it is still valid" do
        expect do
          post refresh_token_endpoint_url(
            client: @client, refresh_token: @token.refresh_token,
          )
        end.not_to change(Doorkeeper::AccessToken, :count)
      end

      it "creates a new access token when refresh token has expired" do
        @token.update!(expires_in: 0)
        expect do
          post refresh_token_endpoint_url(
            client: @client, refresh_token: @token.refresh_token,
          )
        end.to change(Doorkeeper::AccessToken, :count).by(1)
      end
    end

    context "when refresh_token revoked on use" do
      it "client requests a token with refresh token" do
        post refresh_token_endpoint_url(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).not_to be_revoked
      end

      it "client requests a token with expired access token" do
        @token.update_attribute :expires_in, -100
        post refresh_token_endpoint_url(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).not_to be_revoked
      end
    end

    context "when refresh_token revoked on refresh_token request" do
      before do
        allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
      end

      it "client request a token with refresh token" do
        post refresh_token_endpoint_url(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).to be_revoked
      end

      it "client request a token with expired access token" do
        @token.update_attribute :expires_in, -100
        post refresh_token_endpoint_url(
          client: @client, refresh_token: @token.refresh_token,
        )
        expect(json_response).to include(
          "refresh_token" => Doorkeeper::AccessToken.last.refresh_token,
        )
        expect(@token.reload).to be_revoked
      end
    end

    context "with public & private clients" do
      let(:public_client) do
        FactoryBot.create(
          :application,
          confidential: false,
        )
      end

      let(:token_for_private_client) do
        FactoryBot.create(
          :access_token,
          application: @client,
          resource_owner_id: resource_owner.id,
          resource_owner_type: resource_owner.class.name,
          use_refresh_token: true,
        )
      end

      let(:token_for_public_client) do
        FactoryBot.create(
          :access_token,
          application: public_client,
          resource_owner_id: resource_owner.id,
          resource_owner_type: resource_owner.class.name,
          use_refresh_token: true,
        )
      end

      it "issues a new token without client_secret when refresh token was issued to a public client" do
        post refresh_token_endpoint_url(
          client_id: public_client.uid,
          refresh_token: token_for_public_client.refresh_token,
        )

        new_token = Doorkeeper::AccessToken.last
        expect(json_response).to include(
          "access_token" => new_token.token,
          "refresh_token" => new_token.refresh_token,
        )
      end

      it "returns an error without credentials" do
        post refresh_token_endpoint_url(refresh_token: token_for_private_client.refresh_token)

        expect(json_response).to include("error" => "invalid_grant")
      end

      it "returns an error with wrong credentials" do
        post refresh_token_endpoint_url(
          client_id: "1",
          client_secret: "1",
          refresh_token: token_for_private_client.refresh_token,
        )
        expect(json_response).to match(
          "error" => "invalid_client",
          "error_description" => an_instance_of(String),
        )
      end
    end

    it "client gets an error for invalid refresh token" do
      post refresh_token_endpoint_url(client: @client, refresh_token: "invalid")

      expect(json_response).to match(
        "error" => "invalid_grant",
        "error_description" => an_instance_of(String),
      )
    end

    it "client gets an error for revoked access token" do
      @token.revoke
      post refresh_token_endpoint_url(client: @client, refresh_token: @token.refresh_token)

      expect(json_response).to match(
        "error" => "invalid_grant",
        "error_description" => an_instance_of(String),
      )
    end

    it "second of simultaneous client requests get an error for revoked access token" do
      allow_any_instance_of(Doorkeeper::AccessToken).to receive(:revoked?).and_return(false, true)
      post refresh_token_endpoint_url(client: @client, refresh_token: @token.refresh_token)

      expect(json_response).to match(
        "error" => "invalid_grant",
        "error_description" => an_instance_of(String),
      )
    end
  end

  context "when refreshing the token with multiple sessions (devices)" do
    before do
      # enable password auth to simulate other devices
      config_is_set(:grant_flows, ["password"])
      config_is_set(:resource_owner_from_credentials) do
        User.authenticate! params[:username], params[:password]
      end
      create_resource_owner
      _another_token = post password_token_endpoint_url(
        client: @client, resource_owner: resource_owner,
      )
      last_token.update(created_at: 5.seconds.ago)

      @token = FactoryBot.create(
        :access_token,
        application: @client,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
      @token.update_attribute :expires_in, -100
    end

    context "when refresh_token revoked on use" do
      it "client request a token after creating another token with the same user" do
        post refresh_token_endpoint_url(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("refresh_token" => last_token.refresh_token)
        expect(@token.reload).not_to be_revoked
      end
    end

    context "when refresh_token revoked on refresh_token request" do
      before do
        allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_on_use?).and_return(false)
      end

      it "client request a token after creating another token with the same user" do
        post refresh_token_endpoint_url(
          client: @client, refresh_token: @token.refresh_token,
        )

        expect(json_response).to include("refresh_token" => last_token.refresh_token)
        expect(@token.reload).to be_revoked
      end
    end

    def last_token
      Doorkeeper::AccessToken.last_authorized_token_for(
        @client.id, resource_owner,
      )
    end
  end
end

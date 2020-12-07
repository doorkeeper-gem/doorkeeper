# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Revoke Token Flow" do
  before do
    Doorkeeper.configure { orm DOORKEEPER_ORM }
  end

  let(:private_client_application) { FactoryBot.create :application }
  let(:public_client_application) { FactoryBot.create :application, confidential: false }
  let(:resource_owner) { User.create!(name: "John", password: "sekret") }

  context "with authenticated, confidential OAuth 2.0 client/application" do
    let(:access_token) do
      FactoryBot.create(
        :access_token,
        application: private_client_application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
    end

    let(:headers) do
      client_id = private_client_application.uid
      client_secret = private_client_application.secret
      credentials = Base64.encode64("#{client_id}:#{client_secret}")
      { "HTTP_AUTHORIZATION" => "Basic #{credentials}" }
    end

    it "revokes the access token provided" do
      post revocation_token_endpoint_url, params: { token: access_token.token }, headers: headers

      expect(response).to be_successful
      expect(access_token.reload).to be_revoked
    end

    it "revokes the refresh token provided" do
      post revocation_token_endpoint_url, params: { token: access_token.refresh_token }, headers: headers

      expect(response).to be_successful
      expect(access_token.reload).to be_revoked
    end

    context "with invalid token to revoke" do
      it "does not revoke any tokens and must respond with success" do
        expect do
          post revocation_token_endpoint_url,
               params: { token: "I_AM_AN_INVALID_TOKEN" },
               headers: headers
        end.not_to(change { Doorkeeper::AccessToken.where(revoked_at: nil).count })

        expect(response).to be_successful
      end
    end

    context "with bad credentials and a valid token" do
      let(:headers) do
        client_id = private_client_application.uid
        credentials = Base64.encode64("#{client_id}:poop")
        { "HTTP_AUTHORIZATION" => "Basic #{credentials}" }
      end

      it "does not revoke any tokens and respond with forbidden" do
        post revocation_token_endpoint_url, params: { token: access_token.token }, headers: headers

        expect(response).to be_forbidden
        expect(response.body).to include("unauthorized_client")
        expect(response.body).to include(I18n.t("doorkeeper.errors.messages.revoke.unauthorized"))
        expect(access_token.reload).not_to be_revoked
      end
    end

    context "with no credentials and a valid token" do
      it "does not revoke any tokens and respond with forbidden" do
        post revocation_token_endpoint_url, params: { token: access_token.token }

        expect(response).to be_forbidden
        expect(response.body).to include("unauthorized_client")
        expect(response.body).to include(I18n.t("doorkeeper.errors.messages.revoke.unauthorized"))
        expect(access_token.reload).not_to be_revoked
      end
    end

    context "with valid token for another client application" do
      let(:other_client_application) { FactoryBot.create :application }
      let(:headers) do
        client_id = other_client_application.uid
        client_secret = other_client_application.secret
        credentials = Base64.encode64("#{client_id}:#{client_secret}")
        { "HTTP_AUTHORIZATION" => "Basic #{credentials}" }
      end

      it "does not revoke the token as it's unauthorized" do
        post revocation_token_endpoint_url, params: { token: access_token.token }, headers: headers

        expect(response).to be_forbidden
        expect(response.body).to include("unauthorized_client")
        expect(response.body).to include(I18n.t("doorkeeper.errors.messages.revoke.unauthorized"))
        expect(access_token.reload).not_to be_revoked
      end
    end
  end

  context "with authenticated public OAuth 2.0 client/application" do
    let(:access_token) do
      FactoryBot.create(
        :access_token,
        application: nil,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
    end

    it "revokes the access token provided" do
      post revocation_token_endpoint_url,
           params: { client_id: public_client_application.uid, token: access_token.token },
           headers: headers

      expect(response).to be_successful
      expect(access_token.reload).to be_revoked
    end

    it "revokes the refresh token provided" do
      post revocation_token_endpoint_url,
           params: { client_id: public_client_application.uid, token: access_token.refresh_token },
           headers: headers

      expect(response).to be_successful
      expect(access_token.reload).to be_revoked
    end

    it "responses with success even for invalid token" do
      post revocation_token_endpoint_url,
           params: { client_id: public_client_application.uid, token: "dont_exist" },
           headers: headers

      expect(response).to be_successful
    end

    context "with a valid token issued for a confidential client" do
      let(:access_token) do
        FactoryBot.create(
          :access_token,
          application: private_client_application,
          resource_owner_id: resource_owner.id,
          resource_owner_type: resource_owner.class.name,
          use_refresh_token: true,
        )
      end

      it "does not revoke the access token provided" do
        post revocation_token_endpoint_url,
             params: { client_id: public_client_application.uid, token: access_token.token }

        expect(response).to be_forbidden
        expect(response.body).to include("unauthorized_client")
        expect(response.body).to include(I18n.t("doorkeeper.errors.messages.revoke.unauthorized"))
        expect(access_token.reload).not_to be_revoked
      end

      it "does not revoke the refresh token provided" do
        post revocation_token_endpoint_url,
             params: { client_id: public_client_application.uid, token: access_token.refresh_token }

        expect(response).to be_forbidden
        expect(response.body).to include("unauthorized_client")
        expect(response.body).to include(I18n.t("doorkeeper.errors.messages.revoke.unauthorized"))
        expect(access_token.reload).not_to be_revoked
      end
    end
  end

  context "without client authentication, when skip_client_authentication_for_password_grant is false (the default)" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        skip_client_authentication_for_password_grant false
      end
    end

    let(:access_token) do
      FactoryBot.create(
        :access_token,
        application: nil,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
    end

    it "does not remove the token and responses with an error" do
      post revocation_token_endpoint_url,
           params: { token: access_token.token },
           headers: headers

      expect(response).not_to be_successful
      expect(access_token.reload).not_to be_revoked
    end
  end

  context "without client authentication, when skip_client_authentication_for_password_grant is true" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        skip_client_authentication_for_password_grant true
      end
    end

    let(:access_token) do
      FactoryBot.create(
        :access_token,
        application: nil,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        use_refresh_token: true,
      )
    end

    it "revokes the access token provided" do
      post revocation_token_endpoint_url,
           params: { client_id: public_client_application.uid, token: access_token.token },
           headers: headers

      expect(response).to be_successful
      expect(access_token.reload).to be_revoked
    end
  end
end

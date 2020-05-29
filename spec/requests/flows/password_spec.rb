# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Resource Owner Password Credentials Flow" do
  context "when not setup properly" do
    before do
      client_exists
      create_resource_owner
    end

    context "with valid user credentials" do
      it "does not issue new token" do
        expect do
          post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        end.not_to(change { Doorkeeper::AccessToken.count })
      end
    end
  end

  context "when grant type configured" do
    let(:client_attributes) { { redirect_uri: nil } }

    before do
      config_is_set(:grant_flows, ["password"])
      config_is_set(:resource_owner_from_credentials) { User.authenticate! params[:username], params[:password] }
      client_exists(client_attributes)
      create_resource_owner
    end

    context "with valid user credentials" do
      context "with confidential client authorized using Basic auth" do
        it "issues a new token" do
          expect do
            post password_token_endpoint_url(
              resource_owner: @resource_owner,
            ), headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }
          end.to(change { Doorkeeper::AccessToken.count })

          token = Doorkeeper::AccessToken.first
          expect(token.application_id).to eq(@client.id)

          expect(json_response).to match(
            "access_token" => token.token,
            "expires_in" => an_instance_of(Integer),
            "token_type" => "Bearer",
            "created_at" => an_instance_of(Integer),
          )
        end
      end

      context "with non-confidential/public client" do
        let(:client_attributes) { { confidential: false } }

        context "when configured to check application supported grant flow" do
          before do
            Doorkeeper.configuration.instance_variable_set(
              :@allow_grant_flow_for_client,
              ->(_grant_flow, client) { client.name == "admin" },
            )
          end

          scenario "forbids the request when doesn't satisfy condition" do
            @client.update(name: "sample app")

            expect do
              post password_token_endpoint_url(
                client_id: @client.uid,
                client_secret: "foobar",
                resource_owner: @resource_owner,
              )
            end.not_to(change { Doorkeeper::AccessToken.count })

            expect(response.status).to eq(401)
            expect(json_response).to match(
              "error" => "invalid_client",
              "error_description" => an_instance_of(String),
            )
          end

          scenario "allows the request when satisfies condition" do
            @client.update(name: "admin")

            expect do
              post password_token_endpoint_url(client_id: @client.uid, resource_owner: @resource_owner)
            end.to change { Doorkeeper::AccessToken.count }.by(1)

            token = Doorkeeper::AccessToken.first
            expect(token.application_id).to eq(@client.id)

            expect(json_response).to include("access_token" => token.token)
          end
        end

        context "when client_secret absent" do
          it "issues a new token" do
            expect do
              post password_token_endpoint_url(client_id: @client.uid, resource_owner: @resource_owner)
            end.to change { Doorkeeper::AccessToken.count }.by(1)

            token = Doorkeeper::AccessToken.first

            expect(token.application_id).to eq(@client.id)
            expect(json_response).to include("access_token" => token.token)
          end
        end

        context "when client_secret present" do
          it "issues a new token" do
            expect do
              post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
            end.to change { Doorkeeper::AccessToken.count }.by(1)

            token = Doorkeeper::AccessToken.first

            expect(token.application_id).to eq(@client.id)
            expect(json_response).to include("access_token" => token.token)
          end

          context "when client_secret incorrect" do
            it "doesn't issue new token" do
              expect do
                post password_token_endpoint_url(
                  client_id: @client.uid,
                  client_secret: "foobar",
                  resource_owner: @resource_owner,
                )
              end.not_to(change { Doorkeeper::AccessToken.count })

              expect(response.status).to eq(401)
              expect(json_response).to include(
                "error" => "invalid_client",
                "error_description" => an_instance_of(String),
              )
            end
          end
        end
      end

      context "with confidential/private client" do
        it "issues a new token" do
          expect do
            post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          token = Doorkeeper::AccessToken.first

          expect(token.application_id).to eq(@client.id)
          expect(json_response).to include("access_token" => token.token)
        end

        context "when client_secret absent" do
          it "doesn't issue new token" do
            expect do
              post password_token_endpoint_url(client_id: @client.uid, resource_owner: @resource_owner)
            end.not_to(change { Doorkeeper::AccessToken.count })

            expect(response.status).to eq(401)
            expect(json_response).to match(
              "error" => "invalid_client",
              "error_description" => an_instance_of(String),
            )
          end
        end
      end

      it "issues a refresh token if enabled" do
        config_is_set(:refresh_token_enabled, true)

        post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)

        token = Doorkeeper::AccessToken.first
        expect(json_response).to include("refresh_token" => token.refresh_token)
      end

      it "returns the same token if it is still accessible" do
        allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)

        client_is_authorized(@client, @resource_owner)

        post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)

        expect(Doorkeeper::AccessToken.count).to be(1)
        expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
      end

      context "with valid, default scope" do
        before do
          default_scopes_exist :public
        end

        it "issues new token" do
          expect do
            post password_token_endpoint_url(client: @client, resource_owner: @resource_owner, scope: "public")
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          token = Doorkeeper::AccessToken.first

          expect(token.application_id).to eq(@client.id)
          expect(json_response).to include(
            "access_token" => token.token,
            "scope" => "public",
          )
        end
      end
    end

    context "with skip_client_authentication_for_password_grant config option" do
      context "when enabled" do
        before do
          allow(Doorkeeper.config)
            .to receive(:skip_client_authentication_for_password_grant).and_return(true)
        end

        it "issues a new token without client credentials" do
          expect do
            post password_token_endpoint_url(resource_owner: @resource_owner)
          end.to(change { Doorkeeper::AccessToken.count }.by(1))

          token = Doorkeeper::AccessToken.first

          expect(token.application_id).to be_nil
          expect(json_response).to include("access_token" => token.token)
        end
      end

      context "when disabled" do
        before do
          allow(Doorkeeper.config)
            .to receive(:skip_client_authentication_for_password_grant).and_return(false)
        end

        it "doesn't issue a new token without client credentials" do
          expect do
            post password_token_endpoint_url(resource_owner: @resource_owner)
          end.not_to(change { Doorkeeper::AccessToken.count })

          expect(response.status).to eq(401)
          expect(json_response).to match(
            "error" => "invalid_client",
            "error_description" => an_instance_of(String),
          )
        end
      end
    end

    context "when application scopes are present and differs from configured default scopes and no scope is passed" do
      before do
        default_scopes_exist :public
        @client.update(scopes: "abc")
      end

      it "issues new token without any scope" do
        expect do
          post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        token = Doorkeeper::AccessToken.first

        expect(token.application_id).to eq(@client.id)
        expect(token.scopes).to be_empty
        expect(json_response).to include("access_token" => token.token)
        expect(json_response).not_to include("scope")
      end
    end

    context "when application scopes contain some of the default scopes and no scope is passed" do
      before do
        @client.update(scopes: "read write public")
      end

      it "issues new token with one default scope that are present in application scopes" do
        default_scopes_exist :public, :admin

        expect do
          post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        token = Doorkeeper::AccessToken.first

        expect(token.application_id).to eq(@client.id)
        expect(json_response).to include(
          "access_token" => token.token,
          "scope" => "public",
        )
      end

      it "issues new token with multiple default scopes that are present in application scopes" do
        default_scopes_exist :public, :read, :update

        expect do
          post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        token = Doorkeeper::AccessToken.first

        expect(token.application_id).to eq(@client.id)
        expect(json_response).to include(
          "access_token" => token.token,
          "scope" => "public read",
        )
      end
    end

    context "with invalid scopes" do
      it "doesn't issue new token" do
        expect do
          post password_token_endpoint_url(
            client: @client,
            resource_owner: @resource_owner,
            scope: "random",
          )
        end.not_to(change { Doorkeeper::AccessToken.count })
      end

      it "returns invalid_scope error" do
        post password_token_endpoint_url(
          client: @client,
          resource_owner: @resource_owner,
          scope: "random",
        )

        expect(response.status).to eq(400)
        expect(json_response).to match(
          "error" => "invalid_scope",
          "error_description" => translated_error_message(:invalid_scope),
        )
      end
    end

    context "with invalid user credentials" do
      it "doesn't issue new token with bad password" do
        expect do
          post password_token_endpoint_url(
            client: @client,
            resource_owner_username: @resource_owner.name,
            resource_owner_password: "wrongpassword",
          )
        end.not_to(change { Doorkeeper::AccessToken.count })
      end

      it "doesn't issue new token without credentials" do
        expect do
          post password_token_endpoint_url(client: @client)
        end.not_to(change { Doorkeeper::AccessToken.count })
      end

      it "doesn't issue new token if resource_owner_from_credentials returned false or nil" do
        config_is_set(:resource_owner_from_credentials) { false }

        expect do
          post password_token_endpoint_url(client: @client)
        end.not_to(change { Doorkeeper::AccessToken.count })

        config_is_set(:resource_owner_from_credentials) { nil }

        expect do
          post password_token_endpoint_url(client: @client)
        end.not_to(change { Doorkeeper::AccessToken.count })
      end
    end

    context "with invalid confidential client credentials" do
      it "doesn't issue new token with bad client credentials" do
        expect do
          post password_token_endpoint_url(
            client_id: @client.uid,
            client_secret: "bad_secret",
            resource_owner: @resource_owner,
          )
        end.not_to(change { Doorkeeper::AccessToken.count })
      end
    end

    context "with invalid public client id" do
      it "doesn't issue new token with bad client id" do
        expect do
          post password_token_endpoint_url(client_id: "bad_id", resource_owner: @resource_owner)
        end.not_to(change { Doorkeeper::AccessToken.count })
      end
    end
  end
end

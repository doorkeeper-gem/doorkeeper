# frozen_string_literal: true

require "spec_helper"

describe "Resource Owner Password Credentials Flow not set up" do
  before do
    client_exists
    create_resource_owner
  end

  context "with valid user credentials" do
    it "does not issue new token" do
      expect do
        post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
      end.to_not(change { Doorkeeper::AccessToken.count })
    end
  end
end

describe "Resource Owner Password Credentials Flow" do
  let(:client_attributes) { { redirect_uri: nil } }

  before do
    config_is_set(:grant_flows, ["password"])
    config_is_set(:resource_owner_from_credentials) { User.authenticate! params[:username], params[:password] }
    client_exists(client_attributes)
    create_resource_owner
  end

  context "with valid user credentials" do
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
          should_have_json "error", "invalid_client"
        end

        scenario "allows the request when satisfies condition" do
          @client.update(name: "admin")

          expect do
            post password_token_endpoint_url(client_id: @client.uid, resource_owner: @resource_owner)
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          token = Doorkeeper::AccessToken.first

          expect(token.application_id).to eq @client.id
          should_have_json "access_token", token.token
        end
      end

      context "when client_secret absent" do
        it "should issue new token" do
          expect do
            post password_token_endpoint_url(client_id: @client.uid, resource_owner: @resource_owner)
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          token = Doorkeeper::AccessToken.first

          expect(token.application_id).to eq @client.id
          should_have_json "access_token", token.token
        end
      end

      context "when client_secret present" do
        it "should issue new token" do
          expect do
            post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
          end.to change { Doorkeeper::AccessToken.count }.by(1)

          token = Doorkeeper::AccessToken.first

          expect(token.application_id).to eq @client.id
          should_have_json "access_token", token.token
        end

        context "when client_secret incorrect" do
          it "should not issue new token" do
            expect do
              post password_token_endpoint_url(
                client_id: @client.uid,
                client_secret: "foobar",
                resource_owner: @resource_owner,
              )
            end.not_to(change { Doorkeeper::AccessToken.count })

            expect(response.status).to eq(401)
            should_have_json "error", "invalid_client"
          end
        end
      end
    end

    context "with confidential/private client" do
      it "should issue new token" do
        expect do
          post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        token = Doorkeeper::AccessToken.first

        expect(token.application_id).to eq @client.id
        should_have_json "access_token", token.token
      end

      context "when client_secret absent" do
        it "should not issue new token" do
          expect do
            post password_token_endpoint_url(client_id: @client.uid, resource_owner: @resource_owner)
          end.not_to(change { Doorkeeper::AccessToken.count })

          expect(response.status).to eq(401)
          should_have_json "error", "invalid_client"
        end
      end
    end

    it "should issue new token without client credentials" do
      expect do
        post password_token_endpoint_url(resource_owner: @resource_owner)
      end.to(change { Doorkeeper::AccessToken.count }.by(1))

      token = Doorkeeper::AccessToken.first

      expect(token.application_id).to be_nil
      should_have_json "access_token", token.token
    end

    it "should issue a refresh token if enabled" do
      config_is_set(:refresh_token_enabled, true)

      post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)

      token = Doorkeeper::AccessToken.first

      should_have_json "refresh_token", token.refresh_token
    end

    it "should return the same token if it is still accessible" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)

      client_is_authorized(@client, @resource_owner)

      post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)

      expect(Doorkeeper::AccessToken.count).to be(1)
      should_have_json "access_token", Doorkeeper::AccessToken.first.token
    end

    context "with valid, default scope" do
      before do
        default_scopes_exist :public
      end

      it "should issue new token" do
        expect do
          post password_token_endpoint_url(client: @client, resource_owner: @resource_owner, scope: "public")
        end.to change { Doorkeeper::AccessToken.count }.by(1)

        token = Doorkeeper::AccessToken.first

        expect(token.application_id).to eq @client.id
        should_have_json "access_token", token.token
        should_have_json "scope", "public"
      end
    end

    context "with a token_creation_wrapper" do
      it "wraps token creation" do
        # Creating the wrapper here so we have access to wrapper_count
        wrapper_count = 0
        wrapper = ->(&block) do
          wrapper_count += 1
          block.call(repeat_find: false)
        end
        config_is_set(:token_creation_wrapper, wrapper)

        post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        token = Doorkeeper::AccessToken.first
        should_have_json "access_token", token.token
        expect(wrapper_count).to eq 1

        post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
        token = Doorkeeper::AccessToken.last
        should_have_json "access_token", token.token
        expect(wrapper_count).to eq 2
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

      expect(token.application_id).to eq @client.id
      expect(token.scopes).to be_empty
      should_have_json "access_token", token.token
      should_not_have_json "scope"
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

      expect(token.application_id).to eq @client.id
      should_have_json "access_token", token.token
      should_have_json "scope", "public"
    end

    it "issues new token with multiple default scopes that are present in application scopes" do
      default_scopes_exist :public, :read, :update

      expect do
        post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
      end.to change { Doorkeeper::AccessToken.count }.by(1)

      token = Doorkeeper::AccessToken.first

      expect(token.application_id).to eq @client.id
      should_have_json "access_token", token.token
      should_have_json "scope", "public read"
    end
  end

  context "with invalid scopes" do
    subject do
      post password_token_endpoint_url(
        client: @client,
        resource_owner: @resource_owner,
        scope: "random",
      )
    end

    it "should not issue new token" do
      expect { subject }.to_not(change { Doorkeeper::AccessToken.count })
    end

    it "should return invalid_scope error" do
      subject
      should_have_json "error", "invalid_scope"
      should_have_json "error_description", translated_error_message(:invalid_scope)
      should_not_have_json "access_token"

      expect(response.status).to eq(400)
    end
  end

  context "with invalid user credentials" do
    it "should not issue new token with bad password" do
      expect do
        post password_token_endpoint_url(
          client: @client,
          resource_owner_username: @resource_owner.name,
          resource_owner_password: "wrongpassword",
        )
      end.to_not(change { Doorkeeper::AccessToken.count })
    end

    it "should not issue new token without credentials" do
      expect do
        post password_token_endpoint_url(client: @client)
      end.to_not(change { Doorkeeper::AccessToken.count })
    end

    it "should not issue new token if resource_owner_from_credentials returned false or nil" do
      config_is_set(:resource_owner_from_credentials) { false }

      expect do
        post password_token_endpoint_url(client: @client)
      end.to_not(change { Doorkeeper::AccessToken.count })

      config_is_set(:resource_owner_from_credentials) { nil }

      expect do
        post password_token_endpoint_url(client: @client)
      end.to_not(change { Doorkeeper::AccessToken.count })
    end
  end

  context "with invalid confidential client credentials" do
    it "should not issue new token with bad client credentials" do
      expect do
        post password_token_endpoint_url(
          client_id: @client.uid,
          client_secret: "bad_secret",
          resource_owner: @resource_owner,
        )
      end.to_not(change { Doorkeeper::AccessToken.count })
    end
  end

  context "with invalid public client id" do
    it "should not issue new token with bad client id" do
      expect do
        post password_token_endpoint_url(client_id: "bad_id", resource_owner: @resource_owner)
      end.to_not(change { Doorkeeper::AccessToken.count })
    end
  end
end

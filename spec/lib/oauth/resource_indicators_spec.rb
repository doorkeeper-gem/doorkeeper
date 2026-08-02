# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Resource Indicators (RFC 8707)" do
  let(:application) { FactoryBot.create(:application) }
  let(:resource_owner) { FactoryBot.create(:resource_owner) }
  let(:resource_uri) { "https://api.example.com/" }
  let(:second_resource_uri) { "https://calendar.example.com/" }

  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      resource_indicator_validator ->(_indicators, _client) { true }
    end
  end

  describe "PreAuthorization" do
    subject(:pre_auth) { Doorkeeper::OAuth::PreAuthorization.new(server, parameters, resource_owner) }

    let(:server) do
      double(
        :server,
        default_scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        authorization_response_flows: Doorkeeper.config.authorization_response_flows,
        refresh_token_enabled?: false,
      )
    end

    let(:parameters) do
      {
        client_id: application.uid,
        response_type: "code",
        redirect_uri: application.redirect_uri,
        scope: "public",
        resource: [resource_uri],
      }
    end

    it "is authorizable with valid resource indicators" do
      expect(pre_auth).to be_authorizable
      expect(pre_auth.resource_indicators).to eq([resource_uri])
    end

    it "is authorizable with multiple resource indicators" do
      parameters[:resource] = [resource_uri, second_resource_uri]
      expect(pre_auth).to be_authorizable
      expect(pre_auth.resource_indicators).to eq([resource_uri, second_resource_uri])
    end

    it "deduplicates repeated resource indicators" do
      parameters[:resource] = [resource_uri, resource_uri]
      expect(pre_auth).to be_authorizable
      expect(pre_auth.resource_indicators).to eq([resource_uri])
    end

    it "is authorizable without resource indicators (optional parameter)" do
      parameters.delete(:resource)
      expect(pre_auth).to be_authorizable
      expect(pre_auth.resource_indicators).to eq([])
    end

    context "when resource indicator is invalid" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          resource_indicator_validator ->(_indicators, _client) { false }
        end
      end

      it "is not authorizable" do
        expect(pre_auth).not_to be_authorizable
        expect(pre_auth.error).to eq(Doorkeeper::Errors::InvalidTarget)
      end
    end

    context "when resource URI has a fragment" do
      before { parameters[:resource] = ["https://api.example.com/#frag"] }

      it "is not authorizable" do
        expect(pre_auth).not_to be_authorizable
        expect(pre_auth.error).to eq(Doorkeeper::Errors::InvalidTarget)
      end
    end

    context "when resource URI is relative" do
      before { parameters[:resource] = ["/path"] }

      it "is not authorizable" do
        expect(pre_auth).not_to be_authorizable
        expect(pre_auth.error).to eq(Doorkeeper::Errors::InvalidTarget)
      end
    end

    context "when resource_indicator_validator is nil (feature disabled)" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
        end
      end

      it "is authorizable regardless of resource parameter" do
        parameters[:resource] = ["/invalid"]
        expect(pre_auth).to be_authorizable
      end
    end
  end

  describe "Authorization Code Grant" do
    let(:access_grant) do
      FactoryBot.create(
        :access_grant,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: "#{resource_uri} #{second_resource_uri}",
      )
    end

    context "with token request specifying resource subset" do
      let(:request) do
        Doorkeeper::OAuth::AuthorizationCodeRequest.new(
          Doorkeeper.config,
          access_grant,
          application,
          redirect_uri: access_grant.redirect_uri,
          code_verifier: nil,
          resource: [resource_uri],
        )
      end

      it "issues a token with the requested resource subset" do
        request.authorize
        token = Doorkeeper::AccessToken.last
        expect(token.resource).to eq(resource_uri)
      end
    end

    context "with token request specifying resource not in grant" do
      let(:request) do
        Doorkeeper::OAuth::AuthorizationCodeRequest.new(
          Doorkeeper.config,
          access_grant,
          application,
          redirect_uri: access_grant.redirect_uri,
          code_verifier: nil,
          resource: ["https://other.example.com/"],
        )
      end

      it "rejects the request with invalid_target" do
        response = request.authorize
        expect(response).to be_a(Doorkeeper::OAuth::ErrorResponse)
        expect(response.body[:error]).to eq(:invalid_target)
      end
    end

    context "without resource parameter on token request" do
      let(:request) do
        Doorkeeper::OAuth::AuthorizationCodeRequest.new(
          Doorkeeper.config,
          access_grant,
          application,
          redirect_uri: access_grant.redirect_uri,
          code_verifier: nil,
        )
      end

      it "issues a token bound to the grant's resource set" do
        request.authorize
        token = Doorkeeper::AccessToken.last
        expect(token.resource).to eq("#{resource_uri} #{second_resource_uri}")
      end
    end

    context "when validator is disabled but grant has stored resources" do
      before do
        # Simulate the validator being removed after the grant was issued
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          default_scopes :public
        end
      end

      let(:request) do
        Doorkeeper::OAuth::AuthorizationCodeRequest.new(
          Doorkeeper.config,
          access_grant,
          application,
          redirect_uri: access_grant.redirect_uri,
          code_verifier: nil,
        )
      end

      it "still carries the grant's resource indicators to the token" do
        request.authorize
        token = Doorkeeper::AccessToken.last
        expect(token.resource).to eq("#{resource_uri} #{second_resource_uri}")
      end
    end

    # Regression: when the validator is not configured, an explicit
    # `resource` parameter on the token request was previously silently
    # ignored and subset enforcement was skipped, allowing a request for
    # an audience outside the grant to succeed.  These tests verify the
    # fix: subset and syntax enforcement run even without a validator
    # when the grant is already audience-restricted.
    context "when validator is not configured (regression coverage)" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          default_scopes :public
        end
      end

      context "with token request specifying resource not in grant" do
        let(:request) do
          Doorkeeper::OAuth::AuthorizationCodeRequest.new(
            Doorkeeper.config,
            access_grant,
            application,
            redirect_uri: access_grant.redirect_uri,
            code_verifier: nil,
            resource: ["https://other.example.com/"],
          )
        end

        it "rejects a resource not in the grant even when the validator is not configured" do
          response = request.authorize
          expect(response).to be_a(Doorkeeper::OAuth::ErrorResponse)
          expect(response.body[:error]).to eq(:invalid_target)
        end
      end

      context "with token request specifying a valid resource subset" do
        let(:request) do
          Doorkeeper::OAuth::AuthorizationCodeRequest.new(
            Doorkeeper.config,
            access_grant,
            application,
            redirect_uri: access_grant.redirect_uri,
            code_verifier: nil,
            resource: [resource_uri],
          )
        end

        it "honors a valid resource subset even when the validator is not configured" do
          request.authorize
          token = Doorkeeper::AccessToken.last
          expect(token.resource).to eq(resource_uri)
        end
      end

      context "without resource parameter on token request" do
        let(:request) do
          Doorkeeper::OAuth::AuthorizationCodeRequest.new(
            Doorkeeper.config,
            access_grant,
            application,
            redirect_uri: access_grant.redirect_uri,
            code_verifier: nil,
          )
        end

        it "inherits the grant's full resource set when resource is omitted and the validator is not configured" do
          request.authorize
          token = Doorkeeper::AccessToken.last
          expect(token.resource).to eq("#{resource_uri} #{second_resource_uri}")
        end
      end
    end
  end

  describe "Client Credentials Grant" do
    let(:client) { Doorkeeper::OAuth::Client.new(application) }

    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :public
        resource_indicator_validator ->(_indicators, _client) { true }
      end
    end

    def issue_token(resource: nil)
      parameters = { scope: "public" }
      parameters[:resource] = resource if resource

      request = Doorkeeper::OAuth::ClientCredentialsRequest.new(
        Doorkeeper.config, client, **parameters,
      )
      request.authorize
      request.access_token
    end

    context "with valid resource indicator" do
      let(:request) do
        Doorkeeper::OAuth::ClientCredentialsRequest.new(
          Doorkeeper.config,
          client,
          scope: "public",
          resource: [resource_uri],
        )
      end

      it "issues a token with the resource indicator" do
        response = request.authorize
        expect(response).to be_a(Doorkeeper::OAuth::TokenResponse)
        token = Doorkeeper::AccessToken.last
        expect(token.resource).to eq(resource_uri)
      end
    end

    context "with invalid resource indicator" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          resource_indicator_validator ->(_indicators, _client) { false }
        end
      end

      let(:request) do
        Doorkeeper::OAuth::ClientCredentialsRequest.new(
          Doorkeeper.config,
          client,
          scope: "public",
          resource: [resource_uri],
        )
      end

      it "rejects the request with invalid_target" do
        response = request.authorize
        expect(response).to be_a(Doorkeeper::OAuth::ErrorResponse)
        expect(response.body[:error]).to eq(:invalid_target)
      end
    end

    context "without resource indicator" do
      let(:request) do
        Doorkeeper::OAuth::ClientCredentialsRequest.new(
          Doorkeeper.config,
          client,
          scope: "public",
        )
      end

      it "issues a token without resource constraint" do
        response = request.authorize
        expect(response).to be_a(Doorkeeper::OAuth::TokenResponse)
        token = Doorkeeper::AccessToken.last
        expect(token.resource).to be_nil
      end
    end

    context "with token reuse enabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          default_scopes :public
          reuse_access_token
          resource_indicator_validator ->(_indicators, _client) { true }
        end
      end

      it "does not reuse an unrestricted token when a resource is requested" do
        unrestricted_token = issue_token

        token = issue_token(resource: [resource_uri])

        expect(token.id).not_to eq(unrestricted_token.id)
        expect(token.resource).to eq(resource_uri)
      end

      it "does not reuse a token bound to a different resource" do
        existing_token = issue_token(resource: [resource_uri])

        token = issue_token(resource: [second_resource_uri])

        expect(token.id).not_to eq(existing_token.id)
        expect(token.resource).to eq(second_resource_uri)
      end

      it "reuses a token bound to the same resource" do
        existing_token = issue_token(resource: [resource_uri])

        token = issue_token(resource: [resource_uri])

        expect(token.id).to eq(existing_token.id)
      end

      it "reuses an unrestricted token when no resource is requested" do
        existing_token = issue_token

        token = issue_token

        expect(token.id).to eq(existing_token.id)
      end

      # The lookup returns only the newest match, so the resource has to be
      # part of it: a client alternating between two resources would otherwise
      # never reuse, since the newest token is always for the other one.
      it "reuses the token bound to the requested resource when a newer one exists for another" do
        existing_token = issue_token(resource: [resource_uri])
        issue_token(resource: [second_resource_uri])

        token = issue_token(resource: [resource_uri])

        expect(token.id).to eq(existing_token.id)
      end
    end

    context "with revoke_previous_client_credentials_token enabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          default_scopes :public
          revoke_previous_client_credentials_token
          resource_indicator_validator ->(_indicators, _client) { true }
        end
      end

      # Existing behaviour, pinned here so the reuse fix above is seen not to
      # change it: this option keeps only one token per client, regardless of
      # the audience the previous one was issued for.
      it "still revokes a token issued for a different resource" do
        existing_token = issue_token(resource: [resource_uri])

        issue_token(resource: [second_resource_uri])

        expect(existing_token.reload).to be_revoked
      end
    end
  end

  describe "Refresh Token Grant" do
    let(:access_token) do
      FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        use_refresh_token: true,
        resource: "#{resource_uri} #{second_resource_uri}",
      )
    end
    let(:credentials) do
      Doorkeeper::OAuth::Client::Credentials.new(application.uid, application.secret)
    end
    let(:client) { Doorkeeper.config.application_model.by_uid_and_secret(credentials.uid, credentials.secret) }

    context "with resource subset" do
      let(:request) do
        Doorkeeper::OAuth::RefreshTokenRequest.new(
          Doorkeeper.config,
          access_token,
          credentials,
          refresh_token: access_token.refresh_token,
          resource: [resource_uri],
        )
      end

      it "issues a new token with the requested resource subset" do
        request.authorize
        new_token = Doorkeeper::AccessToken.order(:created_at).last
        expect(new_token.id).not_to eq(access_token.id)
        expect(new_token.resource).to eq(resource_uri)
      end
    end

    context "with resource not in original token" do
      let(:request) do
        Doorkeeper::OAuth::RefreshTokenRequest.new(
          Doorkeeper.config,
          access_token,
          credentials,
          refresh_token: access_token.refresh_token,
          resource: ["https://other.example.com/"],
        )
      end

      it "rejects with invalid_target" do
        response = request.authorize
        expect(response).to be_a(Doorkeeper::OAuth::ErrorResponse)
        expect(response.body[:error]).to eq(:invalid_target)
      end
    end

    context "without resource parameter" do
      let(:request) do
        Doorkeeper::OAuth::RefreshTokenRequest.new(
          Doorkeeper.config,
          access_token,
          credentials,
          refresh_token: access_token.refresh_token,
        )
      end

      it "inherits resource from the original token" do
        request.authorize
        new_token = Doorkeeper::AccessToken.order(:created_at).last
        expect(new_token.id).not_to eq(access_token.id)
        expect(new_token.resource).to eq("#{resource_uri} #{second_resource_uri}")
      end
    end

    context "when validator is not configured" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          default_scopes :public
        end
      end

      context "with resource not in original token" do
        let(:request) do
          Doorkeeper::OAuth::RefreshTokenRequest.new(
            Doorkeeper.config,
            access_token,
            credentials,
            refresh_token: access_token.refresh_token,
            resource: ["https://other.example.com/"],
          )
        end

        it "rejects a resource not in the original token even when the validator is not configured" do
          response = request.authorize
          expect(response).to be_a(Doorkeeper::OAuth::ErrorResponse)
          expect(response.body[:error]).to eq(:invalid_target)
        end
      end

      context "with a valid resource subset" do
        let(:request) do
          Doorkeeper::OAuth::RefreshTokenRequest.new(
            Doorkeeper.config,
            access_token,
            credentials,
            refresh_token: access_token.refresh_token,
            resource: [resource_uri],
          )
        end

        it "honors a valid resource subset even when the validator is not configured" do
          request.authorize
          new_token = Doorkeeper::AccessToken.order(:created_at).last
          expect(new_token.id).not_to eq(access_token.id)
          expect(new_token.resource).to eq(resource_uri)
        end
      end

      context "without resource parameter" do
        let(:request) do
          Doorkeeper::OAuth::RefreshTokenRequest.new(
            Doorkeeper.config,
            access_token,
            credentials,
            refresh_token: access_token.refresh_token,
          )
        end

        it "inherits the original token's resource when resource is omitted and the validator is not configured" do
          request.authorize
          new_token = Doorkeeper::AccessToken.order(:created_at).last
          expect(new_token.id).not_to eq(access_token.id)
          expect(new_token.resource).to eq("#{resource_uri} #{second_resource_uri}")
        end
      end
    end
  end

  describe "Token Introspection" do
    let(:token_with_resource) do
      FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: resource_uri,
      )
    end

    let(:token_with_multiple_resources) do
      FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: "#{resource_uri} #{second_resource_uri}",
      )
    end

    let(:token_without_resource) do
      FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
      )
    end

    let(:server) do
      double(
        :server,
        credentials: nil,
        context: double(:context, request: double(:request, authorization: "Bearer #{auth_token.token}")),
      )
    end

    let(:auth_token) do
      FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
      )
    end

    before do
      allow(Doorkeeper).to receive(:authenticate).and_return(auth_token)
    end

    it "includes aud as string for single resource" do
      introspection = Doorkeeper::OAuth::TokenIntrospection.new(server, token_with_resource)
      allow(introspection).to receive(:authorized?).and_return(true)

      json = introspection.to_json
      expect(json[:aud]).to eq(resource_uri)
    end

    it "includes aud as array for multiple resources" do
      introspection = Doorkeeper::OAuth::TokenIntrospection.new(server, token_with_multiple_resources)
      allow(introspection).to receive(:authorized?).and_return(true)

      json = introspection.to_json
      expect(json[:aud]).to eq([resource_uri, second_resource_uri])
    end

    it "does not include aud when no resource is set" do
      introspection = Doorkeeper::OAuth::TokenIntrospection.new(server, token_without_resource)
      allow(introspection).to receive(:authorized?).and_return(true)

      json = introspection.to_json
      expect(json).not_to have_key(:aud)
    end
  end

  describe "Metadata Response" do
    it "advertises resource_indicators_supported as true when configured" do
      response = Doorkeeper::OAuth::MetadataResponse.new(
        "https://auth.example.com",
        ->(**_args) { "https://auth.example.com/oauth/authorize" },
      )
      expect(response.body[:resource_indicators_supported]).to be true
    end

    it "advertises resource_indicators_supported as false when not configured" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      response = Doorkeeper::OAuth::MetadataResponse.new(
        "https://auth.example.com",
        ->(**_args) { "https://auth.example.com/oauth/authorize" },
      )
      expect(response.body[:resource_indicators_supported]).to be false
    end
  end

  describe "Token Reuse with Resource Indicators" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :public
        reuse_access_token
        resource_indicator_validator ->(_indicators, _client) { true }
      end
    end

    it "does not reuse a token with a different resource" do
      # Existing token audience-restricted to api
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: resource_uri,
      )

      # Request a token for a different resource
      new_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
        resource: second_resource_uri,
      )

      expect(new_token.id).not_to eq(existing_token.id)
      expect(new_token.resource).to eq(second_resource_uri)
    end

    it "reuses a token with the same resource" do
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: resource_uri,
      )

      reused_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
        resource: resource_uri,
      )

      expect(reused_token.id).to eq(existing_token.id)
    end

    it "does not reuse an unrestricted token when resource is requested" do
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: nil,
      )

      new_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
        resource: resource_uri,
      )

      expect(new_token.id).not_to eq(existing_token.id)
      expect(new_token.resource).to eq(resource_uri)
    end
  end

  describe "Token Reuse with Resource Indicators and no validator configured" do
    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :public
        reuse_access_token
        # deliberately omit resource_indicator_validator
      end
    end

    it "does not reuse a token with a different resource when the validator is not configured" do
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: resource_uri,
      )

      new_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
        resource: second_resource_uri,
      )

      expect(new_token.id).not_to eq(existing_token.id)
      expect(new_token.resource).to eq(second_resource_uri)
    end

    it "does not reuse an unrestricted token when a resource is requested and the validator is not configured" do
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: nil,
      )

      new_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
        resource: resource_uri,
      )

      expect(new_token.id).not_to eq(existing_token.id)
      expect(new_token.resource).to eq(resource_uri)
    end

    it "reuses a token with the same resource when the validator is not configured" do
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: resource_uri,
      )

      reused_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
        resource: resource_uri,
      )

      expect(reused_token.id).to eq(existing_token.id)
    end

    it "reuses an unrestricted token when no resource is requested and the validator is not configured" do
      existing_token = FactoryBot.create(
        :access_token,
        application: application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        scopes: "public",
        resource: nil,
      )

      reused_token = Doorkeeper.config.access_token_model.find_or_create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: Doorkeeper::OAuth::Scopes.from_string("public"),
        expires_in: 7200,
        use_refresh_token: false,
      )

      expect(reused_token.id).to eq(existing_token.id)
    end
  end

  describe "parameter permitting" do
    # Verifies that both the scalar (?resource=uri) and array (?resource[]=uri)
    # wire formats survive strong parameters and reach PreAuthorization.
    # RFC 8707 §2 uses the scalar form; Rails array form is also common.
    it "passes a scalar resource parameter through to PreAuthorization" do
      params = ActionController::Parameters.new(
        client_id: "uid",
        response_type: "code",
        resource: "https://api.example.com/",
      )

      permitted = params.permit(:client_id, :response_type, :resource, resource: [])
      expect(permitted[:resource]).to eq("https://api.example.com/")
    end

    it "passes an array resource parameter through to PreAuthorization" do
      params = ActionController::Parameters.new(
        client_id: "uid",
        response_type: "code",
        resource: ["https://api.example.com/", "https://cal.example.com/"],
      )

      permitted = params.permit(:client_id, :response_type, :resource, resource: [])
      expect(permitted[:resource]).to eq(["https://api.example.com/", "https://cal.example.com/"])
    end
  end
end

# frozen_string_literal: true

shared_examples "enforcing proof of possession using dpop" do
  context "when using dpop", token: :dpop do
    def self.controller(&block)
      super(described_class || ::ApplicationController) do
        def index # rubocop:disable Lint/NestedMethodDefinition
          render plain: "index"
        end

        def doorkeeper_unauthorized_render_options(error: nil) # rubocop:disable Lint/NestedMethodDefinition
          { json: ActiveSupport::JSON.encode(error: error.name, error_description: error.description) }
        end

        instance_eval(&block)
      end
    end

    def build_dpop_proof(ath: Base64.urlsafe_encode64(Digest::SHA256.digest(token_string), padding: false),
                         htm: "GET",
                         htu: "http://test.host/#{controller.controller_path}",
                         signing_key: self.signing_key)
      super
    end

    controller do
      before_action :doorkeeper_authorize!
    end

    it "accepts a valid dpop proof" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof
      get :index

      expect(response).to be_successful
    end

    it "rejects an invalid dpop proof with incorrect request details" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(htm: "X")
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to match(/^Bearer, DPoP/)

      expect(json_response["error"]).to match("invalid_dpop_proof")
      expect(json_response["error_description"]).to match("Invalid DPoP proof")
    end

    it "rejects an invalid dpop proof with ath claim" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(ath: "X")
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to match(/^Bearer, DPoP/)

      expect(json_response["error"]).to match("invalid_dpop_proof")
      expect(json_response["error_description"]).to match("Invalid DPoP proof")
    end

    it "rejects an invalid dpop proof with mismatched public keys" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(signing_key: OpenSSL::PKey::EC.generate("prime256v1"))
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to match(/^Bearer, DPoP/)

      expect(json_response["error"]).to match("invalid_token")
      expect(json_response["error_description"]).to match("Invalid DPoP key binding")
    end

    it "rejects a dpop token received as a bearer token" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to match(/^Bearer.*DPoP algs="ES256 PS256"$/)

      expect(json_response["error"]).to match("invalid_token")
      expect(json_response["error_description"]).to match("The access token is invalid")
    end

    it "rejects a bearer token received as a dpop token", token: :valid do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to match(/^Bearer, DPoP/)

      expect(json_response["error"]).to match("invalid_dpop_proof")
      expect(json_response["error_description"]).to match("Invalid DPoP proof")
    end

    it "rejects an empty dpop proof" do
      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to match(/^Bearer, DPoP/)

      expect(json_response["error"]).to match("invalid_dpop_proof")
      expect(json_response["error_description"]).to match("Invalid DPoP proof")
    end

    it "rejects an unknown token presented via dpop with a bad proof as invalid_token" do
      allow(Doorkeeper::AccessToken).to receive(:by_token).with(token_string).and_return(nil)

      request.env["HTTP_AUTHORIZATION"] = "DPoP #{token_string}"
      request.env["HTTP_DPOP"] = build_dpop_proof(htm: "X")
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to include("Bearer")
      expect(response.header["WWW-Authenticate"]).to include("DPoP")

      expect(json_response["error"]).to match("invalid_token")
    end

    it "rejects a request without an authorization token" do
      request.env["HTTP_DPOP"] = build_dpop_proof
      get :index

      expect(response).to be_unauthorized
      expect(response.header["WWW-Authenticate"]).to include("Bearer")
      expect(response.header["WWW-Authenticate"]).to include("DPoP")
      expect(response.header["WWW-Authenticate"]).to include("error=").twice

      expect(json_response["error"]).to match("invalid_token")
      expect(json_response["error_description"]).to match("The access token is invalid")
    end

    context "when dpop is not supported" do
      before do
        allow(Doorkeeper.config.access_token_model).to receive(:dpop_supported?).and_return(false)
      end

      it "accepts a dpop-bound token presented as a bearer token" do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
        get :index

        expect(response).to be_successful
      end

      it "rejects an invalid token and challenges with only bearer", token: :invalid do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
        get :index

        expect(response).to be_unauthorized
        expect(response.header["WWW-Authenticate"]).to match(/^Bearer/)
        expect(response.header["WWW-Authenticate"]).not_to include("DPoP")

        expect(json_response["error"]).to match("invalid_token")
        expect(json_response["error_description"]).to match("The access token is invalid")
      end
    end

    context "when dpop required" do
      controller do
        before_action { doorkeeper_authorize!(dpop: :required) }
      end

      it "rejects a valid bearer token", token: :valid do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
        get :index

        expect(response).to be_unauthorized
        expect(response.header["WWW-Authenticate"]).to match(/^DPoP/)
        expect(response.header["WWW-Authenticate"]).not_to include("Bearer")

        expect(json_response["error"]).to match("invalid_token")
        expect(json_response["error_description"]).to match("The access token is invalid")
      end

      context "when doorkeeper_token is accessed before require is set" do
        controller do
          before_action { doorkeeper_token }
          before_action { doorkeeper_authorize!(dpop: :required) }
        end

        it "rejects a valid bearer token", token: :valid do
          request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
          get :index

          expect(response).to be_unauthorized
          expect(response.header["WWW-Authenticate"]).to match(/^DPoP/)
          expect(response.header["WWW-Authenticate"]).not_to include("Bearer")

          expect(json_response["error"]).to match("invalid_token")
          expect(json_response["error_description"]).to match("The access token is invalid")
        end
      end
    end

    context "when dpop required because from_dpop_authorization is the only configured access_token_method" do
      before do
        config_is_set(:access_token_methods, %i[from_dpop_authorization])
      end

      it "rejects a valid bearer token", token: :valid do
        request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
        get :index

        expect(response).to be_unauthorized
        expect(response.header["WWW-Authenticate"]).to match(/^DPoP/)
        expect(response.header["WWW-Authenticate"]).not_to include("Bearer")

        expect(json_response["error"]).to match("invalid_token")
        expect(json_response["error_description"]).to match("The access token is invalid")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientIdMetadata::Document do
  let(:url) { "https://client.example.com/oauth-client" }

  def document_body(overrides = {})
    {
      "client_id" => url,
      "client_name" => "Example App",
      "redirect_uris" => ["https://app.example.com/callback"],
      "token_endpoint_auth_method" => "none",
    }.merge(overrides).compact.to_json
  end

  describe ".parse!" do
    it "parses a valid document" do
      document = described_class.parse!(url, document_body)

      expect(document.client_id).to eq(url)
      expect(document.client_name).to eq("Example App")
      expect(document.redirect_uris).to eq(["https://app.example.com/callback"])
      expect(document.token_endpoint_auth_method).to eq("none")
      expect(document).not_to be_confidential
    end

    it "defaults token_endpoint_auth_method to none when absent" do
      body = document_body("token_endpoint_auth_method" => nil)

      document = described_class.parse!(url, body)

      expect(document.token_endpoint_auth_method).to eq("none")
    end

    it "rejects invalid JSON" do
      expect { described_class.parse!(url, "{oops") }
        .to raise_error(described_class::ValidationError, /not valid JSON/)
    end

    it "rejects JSON that is not an object" do
      expect { described_class.parse!(url, "[1,2,3]") }
        .to raise_error(described_class::ValidationError, /not a JSON object/)
    end

    it "rejects a document without a client_id property" do
      expect { described_class.parse!(url, document_body("client_id" => nil)) }
        .to raise_error(described_class::ValidationError, /client_id/)
    end

    it "rejects a client_id that does not match the document URL by simple string comparison" do
      # Even a semantically equivalent URL must not match (RFC 3986 §6.2.1).
      body = document_body("client_id" => "https://CLIENT.example.com/oauth-client")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /does not match/)
    end

    it "rejects a document containing client_secret" do
      body = document_body("client_secret" => "s3cret")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /client_secret/)
    end

    # The name is shown on the consent screen and stored in a string column,
    # so neither an arbitrary JSON value nor an unbounded one may reach it.
    it "rejects a non-string client_name" do
      expect { described_class.parse!(url, document_body("client_name" => { "en" => "App" })) }
        .to raise_error(described_class::ValidationError, /client_name must be a string/)
    end

    it "rejects a client_name longer than the name column can hold" do
      name = "a" * (described_class::MAX_PROPERTY_LENGTH + 1)

      expect { described_class.parse!(url, document_body("client_name" => name)) }
        .to raise_error(described_class::ValidationError, /client_name is longer/)
    end

    # JSON.parse tags a body's bytes as UTF-8 without checking them, so an
    # invalid sequence would otherwise reach the name column and the consent
    # screen that renders it.
    it "rejects a client_name that is not valid UTF-8" do
      body = %({"client_id":"#{url}","client_name":"Ap\xFFp","token_endpoint_auth_method":"none"}).b

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /client_name is not valid UTF-8/)
    end

    it "accepts a client_name right at the maximum length" do
      name = "a" * described_class::MAX_PROPERTY_LENGTH

      expect(described_class.parse!(url, document_body("client_name" => name)).client_name).to eq(name)
    end

    it "rejects a document containing client_secret_expires_at" do
      body = document_body("client_secret_expires_at" => 0)

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /client_secret_expires_at/)
    end

    %w[client_secret_basic client_secret_post client_secret_jwt].each do |method|
      it "rejects the shared-secret auth method #{method}" do
        body = document_body("token_endpoint_auth_method" => method)

        expect { described_class.parse!(url, body) }
          .to raise_error(described_class::ValidationError, /not allowed/)
      end
    end

    it "rejects a configured method that declares uses_shared_secret?" do
      Doorkeeper::ClientAuthentication.register(
        :hmac_flavoured,
        double(matches_request?: false, authenticate: nil, uses_shared_secret?: true),
      )
      config_is_set(:client_authentication, %i[none hmac_flavoured])
      body = document_body("token_endpoint_auth_method" => "hmac_flavoured")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /not allowed/)
    ensure
      Doorkeeper::ClientAuthentication.registered_methods.delete(:hmac_flavoured)
    end

    it "rejects a configured method without a declaration whose name suggests a shared secret" do
      Doorkeeper::ClientAuthentication.register(
        :custom_client_secret_scheme,
        double(matches_request?: false, authenticate: nil),
      )
      config_is_set(:client_authentication, %i[none custom_client_secret_scheme])
      body = document_body("token_endpoint_auth_method" => "custom_client_secret_scheme")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /not allowed/)
    ensure
      Doorkeeper::ClientAuthentication.registered_methods.delete(:custom_client_secret_scheme)
    end

    it "accepts an unluckily named method that declares it uses no shared secret" do
      Doorkeeper::ClientAuthentication.register(
        :client_secretless_auth,
        double(matches_request?: false, authenticate: nil, uses_shared_secret?: false),
      )
      config_is_set(:client_authentication, %i[none client_secretless_auth])
      body = document_body("token_endpoint_auth_method" => "client_secretless_auth")

      document = described_class.parse!(url, body)

      expect(document.token_endpoint_auth_method).to eq("client_secretless_auth")
    ensure
      Doorkeeper::ClientAuthentication.registered_methods.delete(:client_secretless_auth)
    end

    it "rejects a non-string token_endpoint_auth_method" do
      body = document_body("token_endpoint_auth_method" => 42)

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /not allowed/)
    end

    it "rejects auth methods this server is not configured to accept" do
      body = document_body("token_endpoint_auth_method" => "tls_client_auth")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /not supported/)
    end

    context "when a secret-free method is registered and configured" do
      before do
        Doorkeeper::ClientAuthentication.register(
          :tls_client_auth,
          double(matches_request?: false, authenticate: nil),
        )
        config_is_set(:client_authentication, %i[client_secret_basic none tls_client_auth])
      end

      after do
        Doorkeeper::ClientAuthentication.registered_methods.delete(:tls_client_auth)
      end

      it "accepts that method and marks the client confidential" do
        body = document_body("token_endpoint_auth_method" => "tls_client_auth")

        document = described_class.parse!(url, body)

        expect(document.token_endpoint_auth_method).to eq("tls_client_auth")
        expect(document).to be_confidential
      end
    end

    it "rejects redirect_uris that is not an array" do
      body = document_body("redirect_uris" => "https://app.example.com/callback")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /redirect_uris/)
    end

    it "rejects redirect_uris containing non-strings" do
      body = document_body("redirect_uris" => ["https://app.example.com/callback", 7])

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /redirect_uris/)
    end

    it "allows a document without redirect_uris" do
      document = described_class.parse!(url, document_body("redirect_uris" => nil))

      expect(document.redirect_uris).to eq([])
    end

    it "exposes the scope the client restricts itself to" do
      default_scopes_exist :read
      optional_scopes_exist :write

      document = described_class.parse!(url, document_body("scope" => "read write"))

      expect(document.scope).to eq("read write")
    end

    # A client's own scopes replace the server's as the allow-list rather than
    # narrowing them, so a document naming a scope this server never
    # configured would otherwise be issued a token for it.
    it "rejects a scope this authorization server does not configure" do
      default_scopes_exist :read

      expect { described_class.parse!(url, document_body("scope" => "read admin")) }
        .to raise_error(described_class::ValidationError, /does not configure/)
    end

    it "accepts an empty scope" do
      default_scopes_exist :read

      expect(described_class.parse!(url, document_body("scope" => "")).scope).to eq("")
    end

    it "rejects a scope that is not valid UTF-8" do
      default_scopes_exist :read
      body = %({"client_id":"#{url}","token_endpoint_auth_method":"none","scope":"re\xFFad"}).b

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /scope is not valid UTF-8/)
    end

    it "leaves scope nil when the document omits it" do
      expect(described_class.parse!(url, document_body).scope).to be_nil
    end

    it "rejects a non-string scope" do
      expect { described_class.parse!(url, document_body("scope" => %w[read write])) }
        .to raise_error(described_class::ValidationError, /scope must be a string/)
    end

    it "rejects a scope longer than the scopes column can hold" do
      scope = "a" * (described_class::MAX_PROPERTY_LENGTH + 1)

      expect { described_class.parse!(url, document_body("scope" => scope)) }
        .to raise_error(described_class::ValidationError, /scope is longer/)
    end

    it "accepts a well-formed jwks" do
      body = document_body("jwks" => { "keys" => [{ "kty" => "RSA", "n" => "x", "e" => "AQAB" }] })

      document = described_class.parse!(url, body)

      expect(document.jwks["keys"].size).to eq(1)
    end

    it "accepts an empty keys array" do
      document = described_class.parse!(url, document_body("jwks" => { "keys" => [] }))

      expect(document.jwks).to eq("keys" => [])
    end

    it "accepts a string jwks_uri" do
      document = described_class.parse!(url, document_body("jwks_uri" => "https://client.example.com/jwks.json"))

      expect(document.jwks_uri).to eq("https://client.example.com/jwks.json")
    end

    # Without these the malformed value reaches the JWK Set resolver, which
    # indexes into it and raises a TypeError out of the token endpoint.
    [
      ["an array", [{ "kty" => "RSA" }]],
      ["a number", 42],
      ["a string", "not-a-jwks"],
      ["an object without keys", { "kid" => "x" }],
      ["an object whose keys is not an array", { "keys" => { "kid" => "x" } }],
      ["an object whose keys holds non-objects", { "keys" => ["not-a-key"] }],
    ].each do |description, value|
      it "rejects a jwks that is #{description}" do
        expect { described_class.parse!(url, document_body("jwks" => value)) }
          .to raise_error(described_class::ValidationError, /jwks/)
      end
    end

    it "rejects a non-string jwks_uri" do
      expect { described_class.parse!(url, document_body("jwks_uri" => ["https://client.example.com/jwks.json"])) }
        .to raise_error(described_class::ValidationError, /jwks_uri/)
    end

    # RFC 7591 Section 2: the two are mutually exclusive. Preferring one
    # silently would leave the server verifying against a key set the client
    # may not have meant to be authoritative.
    it "rejects a document carrying both jwks and jwks_uri" do
      body = document_body(
        "jwks" => { "keys" => [{ "kty" => "RSA", "n" => "x", "e" => "AQAB" }] },
        "jwks_uri" => "https://client.example.com/jwks.json",
      )

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /must not both be present/)
    end

    # A private_key_jwt document publishing no keys would materialize a
    # confidential client that can never authenticate at the token endpoint,
    # leaving rows and grants behind for it. No spec text requires the keys
    # (RFC 7591 §2 lists jwks/jwks_uri as optional) — hygiene, limited to
    # private_key_jwt by name.
    it "rejects a private_key_jwt document that publishes neither jwks nor jwks_uri" do
      config_is_set(:client_authentication, %i[none private_key_jwt])
      body = document_body("token_endpoint_auth_method" => "private_key_jwt")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /requires jwks or jwks_uri/)
    end

    # A blank jwks_uri is never fetched, so it publishes no more keys than an
    # absent one and must not satisfy the check either.
    it "rejects a private_key_jwt document whose jwks_uri is blank" do
      config_is_set(:client_authentication, %i[none private_key_jwt])
      body = document_body("token_endpoint_auth_method" => "private_key_jwt", "jwks_uri" => "")

      expect { described_class.parse!(url, body) }
        .to raise_error(described_class::ValidationError, /requires jwks or jwks_uri/)
    end

    it "accepts a private_key_jwt document that publishes a jwks_uri" do
      config_is_set(:client_authentication, %i[none private_key_jwt])
      body = document_body(
        "token_endpoint_auth_method" => "private_key_jwt",
        "jwks_uri" => "https://client.example.com/jwks.json",
      )

      expect(described_class.parse!(url, body).token_endpoint_auth_method).to eq("private_key_jwt")
    end
  end
end

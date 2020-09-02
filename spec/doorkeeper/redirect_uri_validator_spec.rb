# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::RedirectUriValidator do
  subject(:client) do
    FactoryBot.create(:application)
  end

  it "is valid when the uri is a uri" do
    client.redirect_uri = "https://example.com/callback"
    expect(client).to be_valid
  end

  # Most mobile and desktop operating systems allow apps to register a custom URL
  # scheme that will launch the app when a URL with that scheme is visited from
  # the system browser.
  #
  # @see https://www.oauth.com/oauth2-servers/redirect-uris/redirect-uris-native-apps/
  it "is valid when the uri is custom native URI" do
    client.redirect_uri = "myapp:/callback"
    expect(client).to be_valid
  end

  it "is valid when the uri has a query parameter" do
    client.redirect_uri = "https://example.com/abcd?xyz=123"
    expect(client).to be_valid
  end

  it "accepts nonstandard oob redirect uri" do
    client.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    expect(client).to be_valid
  end

  it "accepts nonstandard oob:auto redirect uri" do
    client.redirect_uri = "urn:ietf:wg:oauth:2.0:oob:auto"
    expect(client).to be_valid
  end

  it "is invalid when the uri is not a uri" do
    client.redirect_uri = "]"
    expect(client).not_to be_valid
    expect(client.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.invalid_uri"))
  end

  it "is invalid when the uri is relative" do
    client.redirect_uri = "/abcd"
    expect(client).not_to be_valid
    expect(client.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.relative_uri"))
  end

  it "is invalid when the uri has a fragment" do
    client.redirect_uri = "https://example.com/abcd#xyz"
    expect(client).not_to be_valid
    expect(client.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.fragment_present"))
  end

  it "is invalid when scheme resolves to localhost (needs an explict scheme)" do
    client.redirect_uri = "localhost:80"
    expect(client).to be_invalid
    expect(client.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.unspecified_scheme"))
  end

  it "is invalid if an ip address" do
    client.redirect_uri = "127.0.0.1:8080"
    expect(client).to be_invalid
  end

  it "accepts an ip address based URI if a scheme is specified" do
    client.redirect_uri = "https://127.0.0.1:8080"
    expect(client).to be_valid
  end

  it "is invalid when host is not specified" do
    client.redirect_uri = "https://"
    expect(client).to be_invalid
    expect(client.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.invalid_uri"))
  end

  context "when force secured uri configured" do
    it "accepts a valid uri" do
      client.redirect_uri = "https://example.com/callback"
      expect(client).to be_valid
    end

    it "accepts custom scheme redirect uri (as per rfc8252 section 7.1)" do
      client.redirect_uri = "com.example.app:/oauth/callback"
      expect(client).to be_valid
    end

    it "accepts custom scheme redirect uri (as per rfc8252 section 7.1) #2" do
      client.redirect_uri = "com.example.app:/test"
      expect(client).to be_valid
    end

    it "accepts custom scheme redirect uri (common misconfiguration we have decided to allow)" do
      client.redirect_uri = "com.example.app://oauth/callback"
      expect(client).to be_valid
    end

    it "accepts custom scheme redirect uri (common misconfiguration we have decided to allow) #2" do
      client.redirect_uri = "com.example.app://test"
      expect(client).to be_valid
    end

    it "accepts a non secured protocol when disabled" do
      client.redirect_uri = "http://example.com/callback"
      allow(Doorkeeper.configuration).to receive(
        :force_ssl_in_redirect_uri,
      ).and_return(false)
      expect(client).to be_valid
    end

    it "accepts a non secured protocol when conditional option defined" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        force_ssl_in_redirect_uri { |uri| uri.host != "localhost" }
      end

      application = FactoryBot.build(:application, redirect_uri: "http://localhost/callback")
      expect(application).to be_valid

      application = FactoryBot.build(:application, redirect_uri: "https://test.com/callback")
      expect(application).to be_valid

      application = FactoryBot.build(:application, redirect_uri: "http://localhost2/callback")
      expect(application).not_to be_valid

      application = FactoryBot.build(:application, redirect_uri: "https://test.com/callback")
      expect(application).to be_valid
    end

    it "forbids redirect uri if required" do
      client.redirect_uri = "javascript://document.cookie"

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        forbid_redirect_uri { |uri| uri.scheme == "javascript" }
      end

      expect(client).to be_invalid
      expect(client.errors[:redirect_uri].first).to eq("is forbidden by the server.")

      client.redirect_uri = "https://localhost/callback"
      expect(client).to be_valid
    end

    it "invalidates the uri when the uri does not use a secure protocol" do
      client.redirect_uri = "http://example.com/callback"
      expect(client).not_to be_valid
      error = client.errors[:redirect_uri].first
      expect(error).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.secured_uri"))
    end
  end

  context "with multiple redirect uri" do
    it "invalidates the second uri when the first uri is native uri" do
      client.redirect_uri = "urn:ietf:wg:oauth:2.0:oob\nexample.com/callback"
      expect(client).to be_invalid
    end
  end

  context "with blank redirect URI" do
    it "forbids blank redirect uri by default" do
      client.redirect_uri = ""

      expect(client).to be_invalid
      expect(client.errors[:redirect_uri]).not_to be_blank
    end

    it "forbids blank redirect uri by custom condition" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        allow_blank_redirect_uri do |_grant_flows, application|
          application.name == "admin app"
        end
      end

      client.name = "test app"
      client.redirect_uri = ""

      expect(client).to be_invalid
      expect(client.errors[:redirect_uri]).not_to be_blank

      client.name = "admin app"
      expect(client).to be_valid
    end
  end
end

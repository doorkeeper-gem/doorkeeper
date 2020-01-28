# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::RedirectUriValidator do
  subject do
    FactoryBot.create(:application)
  end

  it "is valid when the uri is a uri" do
    subject.redirect_uri = "https://example.com/callback"
    expect(subject).to be_valid
  end

  # Most mobile and desktop operating systems allow apps to register a custom URL
  # scheme that will launch the app when a URL with that scheme is visited from
  # the system browser.
  #
  # @see https://www.oauth.com/oauth2-servers/redirect-uris/redirect-uris-native-apps/
  it "is valid when the uri is custom native URI" do
    subject.redirect_uri = "myapp:/callback"
    expect(subject).to be_valid
  end

  it "is valid when the uri has a query parameter" do
    subject.redirect_uri = "https://example.com/abcd?xyz=123"
    expect(subject).to be_valid
  end

  it "accepts nonstandard oob redirect uri" do
    subject.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    expect(subject).to be_valid
  end

  it "accepts nonstandard oob:auto redirect uri" do
    subject.redirect_uri = "urn:ietf:wg:oauth:2.0:oob:auto"
    expect(subject).to be_valid
  end

  it "is invalid when the uri is not a uri" do
    subject.redirect_uri = "]"
    expect(subject).not_to be_valid
    expect(subject.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.invalid_uri"))
  end

  it "is invalid when the uri is relative" do
    subject.redirect_uri = "/abcd"
    expect(subject).not_to be_valid
    expect(subject.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.relative_uri"))
  end

  it "is invalid when the uri has a fragment" do
    subject.redirect_uri = "https://example.com/abcd#xyz"
    expect(subject).not_to be_valid
    expect(subject.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.fragment_present"))
  end

  it "is invalid when scheme resolves to localhost (needs an explict scheme)" do
    subject.redirect_uri = "localhost:80"
    expect(subject).to be_invalid
    expect(subject.errors[:redirect_uri].first).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.unspecified_scheme"))
  end

  it "is invalid if an ip address" do
    subject.redirect_uri = "127.0.0.1:8080"
    expect(subject).to be_invalid
  end

  it "accepts an ip address based URI if a scheme is specified" do
    subject.redirect_uri = "https://127.0.0.1:8080"
    expect(subject).to be_valid
  end

  context "force secured uri" do
    it "accepts an valid uri" do
      subject.redirect_uri = "https://example.com/callback"
      expect(subject).to be_valid
    end

    it "accepts custom scheme redirect uri (as per rfc8252 section 7.1)" do
      subject.redirect_uri = "com.example.app:/oauth/callback"
      expect(subject).to be_valid
    end

    it "accepts custom scheme redirect uri (as per rfc8252 section 7.1) #2" do
      subject.redirect_uri = "com.example.app:/test"
      expect(subject).to be_valid
    end

    it "accepts custom scheme redirect uri (common misconfiguration we have decided to allow)" do
      subject.redirect_uri = "com.example.app://oauth/callback"
      expect(subject).to be_valid
    end

    it "accepts custom scheme redirect uri (common misconfiguration we have decided to allow) #2" do
      subject.redirect_uri = "com.example.app://test"
      expect(subject).to be_valid
    end

    it "accepts a non secured protocol when disabled" do
      subject.redirect_uri = "http://example.com/callback"
      allow(Doorkeeper.configuration).to receive(
        :force_ssl_in_redirect_uri,
      ).and_return(false)
      expect(subject).to be_valid
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
      subject.redirect_uri = "javascript://document.cookie"

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        forbid_redirect_uri { |uri| uri.scheme == "javascript" }
      end

      expect(subject).to be_invalid
      expect(subject.errors[:redirect_uri].first).to eq("is forbidden by the server.")

      subject.redirect_uri = "https://localhost/callback"
      expect(subject).to be_valid
    end

    it "invalidates the uri when the uri does not use a secure protocol" do
      subject.redirect_uri = "http://example.com/callback"
      expect(subject).not_to be_valid
      error = subject.errors[:redirect_uri].first
      expect(error).to eq(I18n.t("activerecord.errors.models.doorkeeper/application.attributes.redirect_uri.secured_uri"))
    end
  end

  context "multiple redirect uri" do
    it "invalidates the second uri when the first uri is native uri" do
      subject.redirect_uri = "urn:ietf:wg:oauth:2.0:oob\nexample.com/callback"
      expect(subject).to be_invalid
    end
  end

  context "blank redirect URI" do
    it "forbids blank redirect uri by default" do
      subject.redirect_uri = ""

      expect(subject).to be_invalid
      expect(subject.errors[:redirect_uri]).not_to be_blank
    end

    it "forbids blank redirect uri by custom condition" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        allow_blank_redirect_uri do |_grant_flows, application|
          application.name == "admin app"
        end
      end

      subject.name = "test app"
      subject.redirect_uri = ""

      expect(subject).to be_invalid
      expect(subject.errors[:redirect_uri]).not_to be_blank

      subject.name = "admin app"
      expect(subject).to be_valid
    end
  end
end

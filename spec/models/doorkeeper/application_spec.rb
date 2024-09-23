# frozen_string_literal: true

require "spec_helper"
require "bcrypt"

RSpec.describe Doorkeeper::Application do
  let(:new_application) { FactoryBot.build(:application) }
  let(:owner) { FactoryBot.build_stubbed(:doorkeeper_testing_user) }

  let(:uid) { SecureRandom.hex(8) }
  let(:secret) { SecureRandom.hex(8) }

  it "is invalid without a name" do
    new_application.name = nil
    expect(new_application).not_to be_valid
  end

  it "is invalid without determining confidentiality" do
    new_application.confidential = nil
    expect(new_application).not_to be_valid
  end

  it "generates uid on create" do
    expect(new_application.uid).to be_nil
    new_application.save
    expect(new_application.uid).not_to be_nil
  end

  it "generates uid on create if an empty string" do
    new_application.uid = ""
    new_application.save
    expect(new_application.uid).not_to be_blank
  end

  it "generates uid on create unless one is set" do
    new_application.uid = uid
    new_application.save
    expect(new_application.uid).to eq(uid)
  end

  it "is invalid without uid" do
    new_application.save
    new_application.uid = nil
    expect(new_application).not_to be_valid
  end

  it "checks uniqueness of uid" do
    app1 = FactoryBot.create(:application)
    app2 = FactoryBot.create(:application)
    app2.uid = app1.uid
    expect(app2).not_to be_valid
  end

  it "expects database to throw an error when uids are the same" do
    app1 = FactoryBot.create(:application)
    app2 = FactoryBot.create(:application)
    app2.uid = app1.uid
    expect { app2.save!(validate: false) }.to raise_error(uniqueness_error)
  end

  it "generate secret on create" do
    expect(new_application.secret).to be_nil
    new_application.save
    expect(new_application.secret).not_to be_nil
  end

  it "generate secret on create if is blank string" do
    new_application.secret = ""
    new_application.save
    expect(new_application.secret).not_to be_blank
  end

  it "generate secret on create unless one is set" do
    new_application.secret = secret
    new_application.save
    expect(new_application.secret).to eq(secret)
  end

  it "is invalid without secret" do
    new_application.save
    new_application.secret = nil
    expect(new_application).not_to be_valid
  end

  it "is valid without secret if client is public" do
    new_application.confidential = false
    new_application.secret = nil
    expect(new_application).to be_valid
  end

  it "generates a secret using a custom object" do
    module CustomGeneratorArgs
      def self.generate
        "custom_application_secret"
      end
    end

    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      application_secret_generator "CustomGeneratorArgs"
    end

    expect(new_application.secret).to be_nil
    new_application.save
    expect(new_application.secret).to eq("custom_application_secret")
  end

  context "when application_owner is enabled" do
    context "when application owner is not required" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner
        end

        Doorkeeper.run_orm_hooks
      end

      it "is valid given valid attributes" do
        expect(new_application).to be_valid
      end
    end

    context "when application owner is required" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner confirmation: true
        end

        Doorkeeper.run_orm_hooks
      end

      it "is invalid without an owner" do
        expect(new_application).not_to be_valid
      end

      it "is valid with an owner" do
        new_application.owner = owner
        expect(new_application).to be_valid
      end
    end
  end

  describe "redirect URI" do
    context "when grant flows allow blank redirect URI" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows %w[password client_credentials]
        end
      end

      it "is valid without redirect_uri" do
        new_application.save
        new_application.redirect_uri = nil
        expect(new_application).to be_valid
      end
    end

    context "when grant flows require redirect URI" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows %w[password client_credentials authorization_code]
        end
      end

      it "is invalid without redirect_uri" do
        new_application.save
        new_application.redirect_uri = nil
        expect(new_application).not_to be_valid
      end
    end

    context "when blank URI option disabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows %w[password client_credentials]
          allow_blank_redirect_uri false
        end
      end

      it "is invalid without redirect_uri" do
        new_application.save
        new_application.redirect_uri = nil
        expect(new_application).not_to be_valid
      end
    end
  end

  context "with hashing enabled" do
    include_context "with application hashing enabled"
    let(:app) { FactoryBot.create :application }
    let(:default_strategy) { Doorkeeper::SecretStoring::Sha256Hash }

    it "uses SHA256 to avoid additional dependencies" do
      # Ensure token was generated
      app.validate
      expect(app.secret).to eq(default_strategy.transform_secret(app.plaintext_secret))
    end

    context "when bcrypt strategy is configured" do
      # In this text context, we have bcrypt loaded so `bcrypt_present?`
      # will always be true
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets using: "Doorkeeper::SecretStoring::BCrypt"
        end
      end

      it "holds a volatile plaintext and BCrypt secret" do
        expect(app.secret_strategy).to eq Doorkeeper::SecretStoring::BCrypt
        expect(app.plaintext_secret).to be_a(String)
        expect(app.secret).not_to eq(app.plaintext_secret)
        expect { ::BCrypt::Password.create(app.secret) }.not_to raise_error
      end
    end

    it "does not fallback to plain lookup by default" do
      lookup = described_class.by_uid_and_secret(app.uid, app.secret)
      expect(lookup).to eq(nil)

      lookup = described_class.by_uid_and_secret(app.uid, app.plaintext_secret)
      expect(lookup).to eq(app)
    end

    context "with fallback enabled" do
      include_context "with token hashing and fallback lookup enabled"

      it "provides plain and hashed lookup" do
        lookup = described_class.by_uid_and_secret(app.uid, app.secret)
        expect(lookup).to eq(app)

        lookup = described_class.by_uid_and_secret(app.uid, app.plaintext_secret)
        expect(lookup).to eq(app)
      end
    end

    it "does not provide access to secret after loading" do
      lookup = described_class.by_uid_and_secret(app.uid, app.plaintext_secret)
      expect(lookup.plaintext_secret).to be_nil
    end
  end

  describe "destroy related models on cascade" do
    before do
      new_application.save
    end

    let(:resource_owner) { FactoryBot.create(:resource_owner) }

    it "destroys its access grants" do
      FactoryBot.create(
        :access_grant,
        application: new_application,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      )

      expect { new_application.destroy }.to change { Doorkeeper::AccessGrant.count }.by(-1)
    end

    it "destroys its access tokens" do
      FactoryBot.create(:access_token, application: new_application)
      FactoryBot.create(:access_token, application: new_application, revoked_at: Time.now.utc)
      expect do
        new_application.destroy
      end.to change { Doorkeeper::AccessToken.count }.by(-2)
    end
  end

  describe "#ordered_by" do
    let(:applications) { FactoryBot.create_list(:application, 5) }

    context "when a direction is not specified" do
      it "calls order with a default order of asc" do
        names = applications.map(&:name).sort
        expect(described_class.ordered_by(:name).map(&:name)).to eq(names)
      end
    end

    context "when a direction is specified" do
      it "calls order with specified direction" do
        names = applications.map(&:name).sort.reverse
        expect(described_class.ordered_by(:name, :desc).map(&:name)).to eq(names)
      end
    end
  end

  describe "#redirect_uri=" do
    context "when array of valid redirect_uris" do
      it "joins by newline" do
        new_application.redirect_uri = ["http://localhost/callback1", "http://localhost/callback2"]
        expect(new_application.redirect_uri).to eq("http://localhost/callback1\nhttp://localhost/callback2")
      end
    end

    context "when string of valid redirect_uris" do
      it "stores as-is" do
        new_application.redirect_uri = "http://localhost/callback1\nhttp://localhost/callback2"
        expect(new_application.redirect_uri).to eq("http://localhost/callback1\nhttp://localhost/callback2")
      end
    end
  end

  describe "#renew_secret" do
    let(:app) { FactoryBot.create :application }

    it "generates a new secret" do
      old_secret = app.secret
      app.renew_secret
      expect(old_secret).not_to eq(app.secret)
    end
  end

  describe "#authorized_for" do
    let(:resource_owner) { FactoryBot.create(:resource_owner) }
    let(:other_resource_owner) { FactoryBot.create(:resource_owner) }

    it "is empty if the application is not authorized for anyone" do
      expect(described_class.authorized_for(resource_owner)).to be_empty
    end

    it "returns only application for a specific resource owner" do
      FactoryBot.create(
        :access_token,
        resource_owner_id: other_resource_owner.id,
        resource_owner_type: other_resource_owner.class.name,
      )
      token = FactoryBot.create(
        :access_token,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      )
      expect(described_class.authorized_for(resource_owner)).to eq([token.application])
    end

    it "excludes revoked tokens" do
      FactoryBot.create(
        :access_token,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        revoked_at: 2.days.ago,
      )
      expect(described_class.authorized_for(resource_owner)).to be_empty
    end

    it "returns all applications that have been authorized" do
      token1 = FactoryBot.create(
        :access_token,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      )
      token2 = FactoryBot.create(
        :access_token,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
      )
      expect(described_class.authorized_for(resource_owner))
        .to eq([token1.application, token2.application])
    end

    it "returns only one application even if it has been authorized twice" do
      application = FactoryBot.create(:application)
      FactoryBot.create(
        :access_token,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        application: application,
      )
      FactoryBot.create(
        :access_token,
        resource_owner_id: resource_owner.id,
        resource_owner_type: resource_owner.class.name,
        application: application,
      )
      expect(described_class.authorized_for(resource_owner)).to eq([application])
    end
  end

  describe "#revoke_tokens_and_grants_for" do
    it "revokes all access tokens and access grants" do
      application_id = 42
      resource_owner = double
      expect(Doorkeeper::AccessToken)
        .to receive(:revoke_all_for).with(application_id, resource_owner)
      expect(Doorkeeper::AccessGrant)
        .to receive(:revoke_all_for).with(application_id, resource_owner)

      described_class.revoke_tokens_and_grants_for(application_id, resource_owner)
    end
  end

  describe "#by_uid_and_secret" do
    context "when application is private/confidential" do
      it "finds the application via uid/secret" do
        app = FactoryBot.create :application
        authenticated = described_class.by_uid_and_secret(app.uid, app.secret)
        expect(authenticated).to eq(app)
      end

      context "when secret is wrong" do
        it "does not find the application" do
          app = FactoryBot.create :application
          authenticated = described_class.by_uid_and_secret(app.uid, "bad")
          expect(authenticated).to eq(nil)
        end
      end
    end

    context "when application is public/non-confidential" do
      context "when secret is blank" do
        it "finds the application" do
          app = FactoryBot.create :application, confidential: false
          authenticated = described_class.by_uid_and_secret(app.uid, nil)
          expect(authenticated).to eq(app)
        end
      end

      context "when secret is wrong" do
        it "does not find the application" do
          app = FactoryBot.create :application, confidential: false
          authenticated = described_class.by_uid_and_secret(app.uid, "bad")
          expect(authenticated).to eq(nil)
        end
      end
    end
  end

  describe "#confidential?" do
    let(:app) do
      FactoryBot.create(:application, confidential: confidential)
    end

    context "when application is private/confidential" do
      let(:confidential) { true }

      it { expect(app).to be_confidential }
    end

    context "when application is public/non-confidential" do
      let(:confidential) { false }

      it { expect(app).not_to be_confidential }
    end
  end

  describe "#as_json" do
    let(:app) { FactoryBot.create :application, secret: "123123123" }

    before do
      allow(Doorkeeper.configuration)
        .to receive(:application_secret_strategy).and_return(Doorkeeper::SecretStoring::Plain)
    end

    # AR specific feature
    if DOORKEEPER_ORM == :active_record
      it "correctly works with #to_json" do
        ActiveRecord::Base.include_root_in_json = true
        expect(app.to_json(include_root_in_json: true)).to match(/application.+?:\{/)
        ActiveRecord::Base.include_root_in_json = false
      end
    end

    context "when called without authorized resource owner" do
      it "includes minimal set of attributes" do
        expect(app.as_json).to match(
          "id" => app.id,
          "name" => app.name,
          "created_at" => anything,
        )
      end

      it "includes application UID if it's public" do
        app = FactoryBot.create :application, secret: "123123123", confidential: false

        expect(app.as_json).to match(
          "id" => app.id,
          "name" => app.name,
          "created_at" => anything,
          "uid" => app.uid,
        )
      end

      it "respects custom options" do
        expect(app.as_json(except: :id)).not_to include("id")
        expect(app.as_json(only: %i[name created_at secret]))
          .to match(
            "name" => app.name,
            "created_at" => anything,
          )
      end
    end

    context "when called with authorized resource owner" do
      let(:other_owner) { FactoryBot.create(:doorkeeper_testing_user) }
      let(:app) { FactoryBot.create(:application, secret: "123123123", owner: owner) }

      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner confirmation: false
        end

        Doorkeeper.run_orm_hooks
      end

      it "includes all the attributes" do
        expect(app.as_json(current_resource_owner: owner))
          .to include(
            "secret" => "123123123",
            "redirect_uri" => app.redirect_uri,
            "uid" => app.uid,
          )
      end

      it "doesn't include unsafe attributes if current owner isn't the same as owner" do
        expect(app.as_json(current_resource_owner: other_owner))
          .not_to include("redirect_uri")
      end
    end
  end

  if DOORKEEPER_ORM == :active_record
    context "when custom model class configured", active_record: true do
      class CustomApp < ::ActiveRecord::Base
        include Doorkeeper::Orm::ActiveRecord::Mixins::Application
      end

      let(:new_application) { CustomApp.new(FactoryBot.attributes_for(:application)) }

      context "without confirmation" do
        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            application_class "CustomApp"
            enable_application_owner confirmation: false
          end

          Doorkeeper.run_orm_hooks
        end

        it "is valid given valid attributes" do
          expect(new_application).to be_valid
        end
      end

      context "without confirmation" do
        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            application_class "CustomApp"
            enable_application_owner confirmation: true
          end

          Doorkeeper.run_orm_hooks
        end

        it "is invalid without owner" do
          expect(new_application).not_to be_valid
          new_application.owner = owner
          expect(new_application).to be_valid
        end
      end
    end
  end
end

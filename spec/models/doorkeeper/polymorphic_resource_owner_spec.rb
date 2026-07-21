# frozen_string_literal: true

require "spec_helper"

# The dummy application boots with a non-polymorphic Doorkeeper
# configuration, so the polymorphic side of the model mixins is exercised
# here with freshly defined model classes: `included` hooks read the
# configuration at include time, and the dummy schema already carries the
# `resource_owner_type` columns.
RSpec.describe "polymorphic resource owner models" do
  let(:resource_owner) { FactoryBot.create(:doorkeeper_testing_user) }
  let(:application) { FactoryBot.create(:application) }
  let(:scopes) { Doorkeeper::OAuth::Scopes.from_string("public") }

  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_polymorphic_resource_owner
    end

    stub_const(
      "PolyAccessToken",
      Class.new(ApplicationRecord) do
        include Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken
      end,
    )

    stub_const(
      "PolyAccessGrant",
      Class.new(ApplicationRecord) do
        include Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant
      end,
    )
  end

  describe "association setup" do
    it "declares a polymorphic resource_owner on the access token" do
      reflection = PolyAccessToken.reflect_on_association(:resource_owner)

      expect(reflection).not_to be_nil
      expect(reflection.polymorphic?).to be(true)
    end

    it "declares a required polymorphic resource_owner on the access grant" do
      reflection = PolyAccessGrant.reflect_on_association(:resource_owner)

      expect(reflection).not_to be_nil
      expect(reflection.polymorphic?).to be(true)
      expect(PolyAccessGrant.new(application: application).tap(&:valid?).errors[:resource_owner])
        .not_to be_empty
    end
  end

  describe ".create_for" do
    it "persists the resource owner association" do
      token = PolyAccessToken.create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: scopes,
      )

      expect(token).to be_persisted
      expect(token.resource_owner_id).to eq(resource_owner.id)
      expect(token.resource_owner_type).to eq(resource_owner.class.name)
      expect(token.reload.resource_owner).to eq(resource_owner)
    end
  end

  describe ".by_resource_owner" do
    it "filters by both resource owner id and type" do
      token = PolyAccessToken.create_for(
        application: application,
        resource_owner: resource_owner,
        scopes: scopes,
      )
      other_owner = FactoryBot.create(:doorkeeper_testing_user)

      expect(PolyAccessToken.by_resource_owner(resource_owner)).to eq([token])
      expect(PolyAccessToken.by_resource_owner(other_owner)).to be_empty
      expect(PolyAccessToken.by_resource_owner(resource_owner).to_sql)
        .to include("resource_owner_type")
    end
  end

  describe "#same_resource_owner?" do
    it "compares the full polymorphic association" do
      token = PolyAccessToken.create_for(
        application: application, resource_owner: resource_owner, scopes: scopes,
      )
      same_owner_token = PolyAccessToken.create_for(
        application: application, resource_owner: resource_owner, scopes: scopes,
      )
      other_owner_token = PolyAccessToken.create_for(
        application: application,
        resource_owner: FactoryBot.create(:doorkeeper_testing_user),
        scopes: scopes,
      )

      expect(token.same_resource_owner?(same_owner_token)).to be(true)
      expect(token.same_resource_owner?(other_owner_token)).to be(false)
    end
  end

  describe "authorization code exchange" do
    let(:server) do
      double :server,
             access_token_expires_in: 2.days,
             refresh_token_enabled?: false
    end

    before do
      allow(server).to receive(:option_defined?)
        .with(:custom_access_token_expires_in).and_return(false)
      config_is_set(:access_token_class, "PolyAccessToken")
      config_is_set(:access_grant_class, "PolyAccessGrant")
    end

    it "issues the token to the grant's polymorphic resource owner" do
      grant = PolyAccessGrant.create!(
        application: application,
        resource_owner: resource_owner,
        redirect_uri: "https://app.com/callback",
        expires_in: 100,
        scopes: "public",
      )

      Doorkeeper::OAuth::AuthorizationCodeRequest.new(
        server, grant, application, redirect_uri: grant.redirect_uri,
      ).authorize

      new_token = PolyAccessToken.order(:id).last
      expect(new_token.resource_owner).to eq(resource_owner)
    end
  end

  describe "#as_json" do
    it "includes the resource owner type" do
      token = PolyAccessToken.create_for(
        application: application, resource_owner: resource_owner, scopes: scopes,
      )

      expect(token.as_json[:resource_owner_id]).to eq(resource_owner.id)
      expect(token.as_json[:resource_owner_type]).to eq(resource_owner.class.name)
    end
  end
end

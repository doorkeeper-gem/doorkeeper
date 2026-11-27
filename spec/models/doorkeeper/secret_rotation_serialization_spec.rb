# frozen_string_literal: true

require "spec_helper"

RSpec.describe "client secret rotation serialization" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

  describe "serializing an application mid-rotation" do
    before do
      enable_rotation
      retain_current_secret(app)
      app.reload
    end

    it "withholds the rotation columns from every view that does not name them" do
      expect(app.serializable_hash).not_to have_key("old_secret")
      expect(app.as_json).not_to have_key("old_secret_created_at")
      expect(app.serializable_hash(only: %i[old_secret old_secret_created_at])).to be_empty
    end

    it "answers a caller that names one through methods:" do
      serialized = app.serializable_hash(methods: [:old_secret])

      expect(serialized["old_secret"]).to eq(app.read_attribute(:old_secret))
    end
  end

  describe "an inspected application record" do
    it "withholds the retained secret and the timestamp that says a rotation is under way" do
      enable_rotation
      retain_current_secret(app)
      app.reload

      inspected = app.inspect

      expect(inspected).to include("old_secret: [FILTERED]")
      expect(inspected).to include("old_secret_created_at: [FILTERED]")
      expect(inspected).not_to include(app.read_attribute(:old_secret))
    end

    it "names the columns on the model without dropping the host-wide entries" do
      expect(Doorkeeper::Application.filter_attributes)
        .to include(:old_secret, :old_secret_created_at)
      expect(Doorkeeper::Application.filter_attributes)
        .to include(*ActiveRecord::Base.filter_attributes)
    end

    it "composes the host-wide entries once, when the model loads" do
      original = ActiveRecord::Base.filter_attributes
      ActiveRecord::Base.filter_attributes += [:redirect_uri]

      expect(Doorkeeper::AccessToken.filter_attributes).to include(:redirect_uri)
      expect(Doorkeeper::Application.filter_attributes).not_to include(:redirect_uri)
    ensure
      ActiveRecord::Base.filter_attributes = original
    end
  end

  describe "serialization" do
    before do
      enable_rotation
      retain_current_secret(app)
    end

    it "does not expose the retained secret to the public" do
      expect(app.as_json.keys).not_to include("old_secret", "old_secret_created_at")
    end

    it "does not expose it to the owner either" do
      expect(app.as_json(as_owner: true).keys).not_to include("old_secret", "old_secret_created_at")
    end

    it "still gives the owner the attributes they came for" do
      json = app.as_json(as_owner: true)

      expect(json.keys).to include("id", "name", "uid", "secret", "scopes")
    end

    # `enable_application_owner` is a load-time switch (#1831): define the model after turning it on.
    it "does not expose it to a matching current_resource_owner" do
      owner = FactoryBot.create(:doorkeeper_testing_user)
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_application_owner confirmation: false
        enable_secret_rotation
      end

      owned = build_application_model.new(FactoryBot.attributes_for(:application))
      owned.owner = owner
      owned.save!
      retain_current_secret(owned)

      json = owned.as_json(current_resource_owner: owner)

      expect(json.keys).to include("secret", "redirect_uri")
      expect(json.keys).not_to include("old_secret", "old_secret_created_at")
    end

    it "withholds it even when asked for by name" do
      json = app.as_json(as_owner: true, only: %i[id old_secret old_secret_created_at])

      expect(json.keys).to eq(["id"])
    end

    it "withholds it when asked for by name alone" do
      expect(app.as_json(as_owner: true, only: [:old_secret])).to eq({})
    end

    it "keeps an explicit except of the caller's own" do
      json = app.as_json(as_owner: true, except: [:scopes])

      expect(json.keys).not_to include("scopes", "old_secret", "old_secret_created_at")
      expect(json.keys).to include("secret")
    end

    it "accepts only: and except: given as a Set" do
      expect(app.serializable_hash(only: Set[:id, :old_secret]).keys).to eq(["id"])

      keys = app.serializable_hash(except: Set[:scopes]).keys

      expect(keys).not_to include("scopes", "old_secret", "old_secret_created_at")
      expect(keys).to include("secret")
    end

    it "does not expose it through a direct #serializable_hash" do
      hash = app.serializable_hash

      expect(hash.keys).to include("id", "secret")
      expect(hash.keys).not_to include("old_secret", "old_secret_created_at")
    end

    it "withholds it from #serializable_hash even when asked for by name" do
      hash = app.serializable_hash(only: %i[id old_secret old_secret_created_at])

      expect(hash.keys).to eq(["id"])
    end

    it "does not mutate the options it was given" do
      options = { as_owner: true }

      app.as_json(options)

      expect(options).to eq({ as_owner: true })
    end
  end
end

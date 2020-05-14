# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::Scopes do
  subject(:fake_object) do
    Class.new(Struct.new(:scopes)) do
      include Doorkeeper::Models::Scopes
    end.new
  end

  before do
    fake_object[:scopes] = "public admin"
  end

  describe "#scopes" do
    it "is a `Scopes` class" do
      expect(fake_object.scopes).to be_a(Doorkeeper::OAuth::Scopes)
    end

    it "includes scopes" do
      expect(fake_object.scopes).to include("public")
    end
  end

  describe "#scopes=" do
    it "accepts String" do
      fake_object.scopes = "private admin"
      expect(fake_object.scopes_string).to eq("private admin")
    end

    it "accepts Array" do
      fake_object.scopes = %w[private admin]
      expect(fake_object.scopes_string).to eq("private admin")
    end

    it "ignores duplicated scopes" do
      fake_object.scopes = %w[private admin admin]
      expect(fake_object.scopes_string).to eq("private admin")

      fake_object.scopes = "private admin admin"
      expect(fake_object.scopes_string).to eq("private admin")
    end
  end

  describe "#scopes_string" do
    it "is a `Scopes` class" do
      expect(fake_object.scopes_string).to eq("public admin")
    end
  end

  describe "#includes_scope?" do
    it "returns true if at least one scope is included" do
      expect(fake_object.includes_scope?("public", "private")).to be true
    end

    it "returns false if no scopes are included" do
      expect(fake_object.includes_scope?("teacher", "student")).to be false
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/grant_type_access_tokens_generator"

RSpec.describe Doorkeeper::GrantTypeAccessTokensGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path("../tmp/dummy", __FILE__)

  describe "after running the generator" do
    before do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/add_grant_type_to_access_tokens.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
        assert migration.include?(":grant_type")
      end
    end
  end
end

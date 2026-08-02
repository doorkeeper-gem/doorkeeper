# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/secret_rotation_generator"

RSpec.describe Doorkeeper::SecretRotationGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path("tmp/dummy", __dir__)

  describe "after running the generator" do
    before do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_const("ActiveRecord::VERSION::MAJOR", 7)
      stub_const("ActiveRecord::VERSION::MINOR", 1)

      run_generator

      assert_migration "db/migrate/enable_secret_rotation.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[7.1]\n")
        assert migration.include?("add_column :oauth_applications, :old_secret, :string")
        assert migration.include?("add_column :oauth_applications, :old_secret_created_at, :datetime")
        # A job ending grace periods on a deadline selects on the timestamp,
        # which is a range query over every application.
        assert migration.include?("add_index :oauth_applications, :old_secret_created_at")
      end
    end
  end
end

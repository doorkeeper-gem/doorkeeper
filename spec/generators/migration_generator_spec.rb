# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/migration_generator"

RSpec.describe Doorkeeper::MigrationGenerator do
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

      assert_migration "db/migrate/create_doorkeeper_tables.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
      end
    end
  end
end

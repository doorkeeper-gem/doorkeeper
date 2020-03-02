# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/application_owner_generator"

describe "Doorkeeper::ApplicationOwnerGenerator" do
  include GeneratorSpec::TestCase

  tests Doorkeeper::ApplicationOwnerGenerator
  destination ::File.expand_path("../tmp/dummy", __FILE__)

  describe "after running the generator" do
    before :each do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/add_owner_to_application.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/resource_indicators_generator"

RSpec.describe Doorkeeper::ResourceIndicatorsGenerator do
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

      assert_migration "db/migrate/enable_resource_indicators.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[7.1]\n")
        assert migration.include?("add_column :oauth_access_grants, :resource, :text")
        assert migration.include?("add_column :oauth_access_tokens, :resource, :text")
      end
    end
  end
end

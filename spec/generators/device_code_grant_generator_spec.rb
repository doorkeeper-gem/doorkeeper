# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/device_code_grant_generator"

describe "Doorkeeper::DeviceCodeFlowGenerator" do
  include GeneratorSpec::TestCase

  tests Doorkeeper::DeviceCodeGrantGenerator
  destination ::File.expand_path("../tmp/dummy", __FILE__)

  describe "after running the generator" do
    before :each do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/enable_device_code_grant.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
        assert migration.include?(":user_code")
      end
    end
  end
end

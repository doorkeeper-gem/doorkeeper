# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/enable_polymorphic_resource_owner_generator"

RSpec.describe Doorkeeper::EnablePolymorphicResourceOwnerGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path("../tmp/dummy", __FILE__)

  describe "after running the generator" do
    before do
      prepare_destination
      FileUtils.mkdir_p(::File.expand_path("config/initializers", Pathname(destination_root)))
      FileUtils.copy_file(
        ::File.expand_path("../../lib/generators/doorkeeper/templates/initializer.rb", __dir__),
        ::File.expand_path("config/initializers/doorkeeper.rb", Pathname.new(destination_root)),
      )
    end

    it "creates a migration with a version specifier and changes the initializer" do
      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/enable_polymorphic_resource_owner.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
      end

      # generator_spec gem requires such block definition :(
      #
      # rubocop:disable Style/BlockDelimiters
      expect(destination_root).to(have_structure {
        directory "config" do
          directory "initializers" do
            file "doorkeeper.rb" do
              contains "  use_polymorphic_resource_owner"
            end
          end
        end
      })
      # rubocop:enable Style/BlockDelimiters
    end
  end
end

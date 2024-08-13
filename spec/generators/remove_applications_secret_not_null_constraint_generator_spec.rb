# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/remove_applications_secret_not_null_constraint_generator"

RSpec.describe Doorkeeper::RemoveApplicationSecretNotNullConstraint do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path('tmp/dummy', __dir__)

  describe "after running the generator" do
    before do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      run_generator

      assert_migration "db/migrate/remove_applications_secret_not_null_constraint.rb" do |migration|
        assert migration.include?("change_column_null :oauth_applications, :secret")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/previous_refresh_token_generator"

RSpec.describe Doorkeeper::PreviousRefreshTokenGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path('tmp/dummy', __dir__)

  describe "after running the generator" do
    before do
      prepare_destination

      allow_any_instance_of(described_class).to(
        receive(:no_previous_refresh_token_column?).and_return(true),
      )
    end

    it "creates a migration with a version specifier" do
      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/add_previous_refresh_token_to_access_tokens.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
      end
    end

    context "when file already exist" do
      it "does not create a migration" do
        allow_any_instance_of(described_class).to(
          receive(:no_previous_refresh_token_column?).and_call_original,
        )

        run_generator

        assert_no_migration "db/migrate/add_previous_refresh_token_to_access_tokens.rb"
      end
    end
  end
end

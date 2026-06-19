# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/previous_refresh_token_generator"

RSpec.describe Doorkeeper::PreviousRefreshTokenGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path("tmp/dummy", __dir__)

  # Stub the database column check that backs
  # PreviousRefreshTokenGenerator#no_previous_refresh_token_column? rather
  # than stubbing that private method directly.
  #
  # Stubbing a *private* method on a Thor generator through
  # `allow_any_instance_of` transiently (re)defines it on the class, which
  # triggers Thor's `method_added` hook and registers it as a runnable
  # command. Thor then prints `Could not find command "..."` noise while
  # `run_generator` iterates over all commands. Stubbing the underlying
  # `column_exists?` call keeps the test's intent without redefining any
  # method on the generator class.
  def stub_previous_refresh_token_column(exists:)
    allow(ActiveRecord::Base.connection).to receive(:column_exists?).and_call_original
    allow(ActiveRecord::Base.connection)
      .to(receive(:column_exists?)
      .with(:oauth_access_tokens, :previous_refresh_token)
      .and_return(exists))
  end

  describe "after running the generator" do
    before do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_previous_refresh_token_column(exists: false)

      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/add_previous_refresh_token_to_access_tokens.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
      end
    end

    context "when the column already exists" do
      it "does not create a migration" do
        stub_previous_refresh_token_column(exists: true)

        run_generator

        assert_no_migration "db/migrate/add_previous_refresh_token_to_access_tokens.rb"
      end
    end
  end
end

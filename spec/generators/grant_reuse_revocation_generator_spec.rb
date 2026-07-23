# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/grant_reuse_revocation_generator"

RSpec.describe Doorkeeper::GrantReuseRevocationGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path("tmp/dummy", __dir__)

  # Stub the database column check that backs
  # GrantReuseRevocationGenerator#no_access_token_id_column? rather than
  # stubbing that private method directly (see the note in
  # previous_refresh_token_generator_spec.rb about Thor's `method_added`).
  def stub_access_token_id_column(exists:)
    allow(ActiveRecord::Base.connection).to receive(:column_exists?).and_call_original
    allow(ActiveRecord::Base.connection)
      .to(receive(:column_exists?)
      .with(:oauth_access_grants, :access_token_id)
      .and_return(exists))
  end

  describe "after running the generator" do
    before do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_access_token_id_column(exists: false)

      stub_const("ActiveRecord::VERSION::MAJOR", 5)
      stub_const("ActiveRecord::VERSION::MINOR", 0)

      run_generator

      assert_migration "db/migrate/add_access_token_to_access_grants.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[5.0]\n")
      end
    end

    context "when the column already exists" do
      it "does not create a migration" do
        stub_access_token_id_column(exists: true)

        run_generator

        assert_no_migration "db/migrate/add_access_token_to_access_grants.rb"
      end
    end
  end
end

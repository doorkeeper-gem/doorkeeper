# frozen_string_literal: true

require "spec_helper"
require "generators/doorkeeper/refresh_token_scopes_generator"

RSpec.describe Doorkeeper::RefreshTokenScopesGenerator do
  include GeneratorSpec::TestCase

  tests described_class
  destination ::File.expand_path("tmp/dummy", __dir__)

  # Stubs the column check the generator runs rather than its private
  # predicate; see previous_refresh_token_generator_spec.rb for why stubbing
  # a private method on a Thor generator is noisy.
  def stub_refresh_token_scopes_column(exists:)
    allow(ActiveRecord::Base.connection).to receive(:column_exists?).and_call_original
    allow(ActiveRecord::Base.connection)
      .to(receive(:column_exists?)
      .with(:oauth_access_tokens, :refresh_token_scopes)
      .and_return(exists))
  end

  describe "after running the generator" do
    before do
      prepare_destination
    end

    it "creates a migration with a version specifier" do
      stub_refresh_token_scopes_column(exists: false)

      stub_const("ActiveRecord::VERSION::MAJOR", 7)
      stub_const("ActiveRecord::VERSION::MINOR", 1)

      run_generator

      assert_migration "db/migrate/add_refresh_token_scopes_to_access_tokens.rb" do |migration|
        assert migration.include?("ActiveRecord::Migration[7.1]\n")
        assert migration.include?("add_column :oauth_access_tokens, :refresh_token_scopes, :string")
      end
    end

    context "when the column already exists" do
      it "does not create a migration" do
        stub_refresh_token_scopes_column(exists: true)

        run_generator

        assert_no_migration "db/migrate/add_refresh_token_scopes_to_access_tokens.rb"
      end
    end
  end
end

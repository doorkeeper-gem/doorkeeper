require 'spec_helper_integration'
require 'generators/active_record/doorkeeper_tables_generator'

if Doorkeeper.configuration.orm == :active_record
  describe 'DoorkeeperTablesGenerator', 'active record' do
    include GeneratorSpec::TestCase

    tests ActiveRecord::Generators::DoorkeeperTablesGenerator
    destination ::File.expand_path("../../../tmp", __FILE__)

    before :each do
      prepare_destination
    end

    it "creates the migration" do
      run_generator
      assert_migration 'db/migrate/create_doorkeeper_tables.rb'
    end
  end
end

require 'spec_helper_integration'
require 'generators/doorkeeper/migration_generator'

describe 'Doorkeeper::MigrationGenerator' do
  include GeneratorSpec::TestCase

  tests Doorkeeper::MigrationGenerator
  destination ::File.expand_path('../tmp/dummy', __FILE__)

  describe 'after running the generator' do
    class TestUser; end

    before :each do
      allow(Doorkeeper.configuration).
        to receive(:resource_owner_from_credentials).
        and_return(TestUser.new)

      prepare_destination
      run_generator
    end

    it 'creates a migration with Doorkeeper.resource_owner' do
      assert_migration 'db/migrate/create_doorkeeper_tables.rb' do |file|
        expect(file).to include 'test_user'
      end
    end
  end
end

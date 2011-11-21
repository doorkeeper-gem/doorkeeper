require 'spec_helper'
require 'generators/doorkeeper/install_generator'


describe 'Doorkeeper::InstallGenerator' do
  include GeneratorSpec::TestCase

  tests Doorkeeper::InstallGenerator
  destination ::File.expand_path("../tmp/dummy", __FILE__)

  describe "after running the generator" do
    before :each do
      prepare_destination
      run_generator
    end

    it "creates a migration" do
      assert_migration "db/migrate/create_doorkeeper_tables.rb"
    end

    it "creates an initializer file" do
      assert_file 'config/initializers/doorkeeper.rb'
    end
  end
end

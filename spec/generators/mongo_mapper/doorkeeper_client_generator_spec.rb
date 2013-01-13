require 'spec_helper_integration'
require 'generators/mongo_mapper/doorkeeper_client_generator'

if Doorkeeper.configuration.orm_name == :mongo_mapper
  describe 'DoorkeeperClientGenerator', 'mongo_mapper' do
    include GeneratorSpec::TestCase

    tests MongoMapper::Generators::DoorkeeperClientGenerator
    destination ::File.expand_path("../../../tmp", __FILE__)

    before :each do
      prepare_destination
    end

    it "creates all files" do
      run_generator %w(batman)
      assert_file 'app/models/batman.rb', /plugin DoorkeeperClient/, /key :redirect_uri/, /attr_accessible (:[a-z_]+(, )?)+/
      assert_file 'db/indexes.rb', /Batmen.create_indexes/
    end
  end
end

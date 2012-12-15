require 'spec_helper_integration'
require 'generators/active_record/doorkeeper_client_generator'

describe 'DoorkeeperClientGenerator' do
  include GeneratorSpec::TestCase

  tests ActiveRecord::Generators::DoorkeeperClientGenerator
  destination ::File.expand_path("../../../tmp", __FILE__)

  before :each do
    prepare_destination
  end

  it "creates the model and the migration" do
    run_generator %w(shoe)
    assert_file 'app/models/shoe.rb', /doorkeeper_client!/, /attr_accessible (:[a-z_]+(, )?)+/
    assert_migration "db/migrate/create_doorkeeper_client_as_shoes.rb", /CreateDoorkeeperClientAsShoes/, /def change/
  end

  it "updates model if exists" do
    run_generator %w(shoe)
    assert_file 'app/models/shoe.rb'
    run_generator %w(shoe)
    assert_migration "db/migrate/add_doorkeeper_client_to_shoes.rb", /AddDoorkeeperClientToShoes/
  end
end

require 'spec_helper'

class TestClass
  
end

describe GeneratorSpec::TestCase do
  before do
    @klass = Class.new do
      def self.described_class
        TestClass
      end
      include GeneratorSpec::TestCase
    end
    @klass.test_case_instance = double
  end
  
  it 'passes unknown messages on to test_case_instance' do
    expect(@klass.test_case_instance).to receive(:assert_file).with('test')
    @klass.new.assert_file('test')
  end
  
  it 'handles respond_to accordingly' do
    expect(@klass.test_case_instance).to receive(:respond_to?).with(:assert_no_file).and_return(true)
    expect(@klass.new.respond_to?(:assert_no_file)).to be_truthy
  end
end

describe TestGenerator, 'using normal assert methods', :type => 'generator' do
  destination File.expand_path('../../tmp', __FILE__)
  arguments %w(test --test)
  
  before(:all) do
    prepare_destination
    run_generator
  end

  it 'creates a test initializer' do
    assert_file 'config/initializers/test.rb', '# Initializer'
  end

  it 'creates a migration' do
    assert_migration 'db/migrate/create_tests.rb'
  end

  it 'removes files' do
    assert_no_file '.gitignore'
  end
end

describe TestGenerator, 'with contexts', :type => 'generator' do
  destination File.expand_path('../../tmp', __FILE__)
  before { prepare_destination }
  
  context 'with --test flag' do
    before { run_generator %w(test --test) }
    
    it 'creates a test initializer' do
      assert_file 'config/initializers/test.rb', '# Initializer'
    end
  end
  
  context 'without any flags' do
    before { run_generator %w(test) }
    
    it 'doesn\'t create a test initializer' do
      assert_no_file 'config/initializers/test.rb'
    end
  end
end

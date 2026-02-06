# taken from https://github.com/rspec/rspec-rails/blob/master/spec/support/helpers.rb
module Helpers
  def stub_metadata(additional_metadata)
    stub_metadata = metadata_with(additional_metadata)
    allow(RSpec::Core::ExampleGroup).to receive(:metadata) { stub_metadata }
  end

  def metadata_with(additional_metadata)
    ::RSpec.describe("example group").metadata.merge(additional_metadata)
  end

  RSpec.configure {|c| c.include self}
end

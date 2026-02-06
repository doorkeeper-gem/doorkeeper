require 'spec_helper'

module GeneratorSpec
  describe GeneratorExampleGroup do
    it { is_expected.to be_included_in_files_in('./spec/lib/generators/') }
  end
end

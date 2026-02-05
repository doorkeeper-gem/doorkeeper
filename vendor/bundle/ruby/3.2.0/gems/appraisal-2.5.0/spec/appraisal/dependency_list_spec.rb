require "spec_helper"
require "appraisal/dependency_list"

describe Appraisal::DependencyList do
  describe "#add" do
    let(:dependency_list) { Appraisal::DependencyList.new }

    it "adds dependency to the list" do
      dependency_list.add("rails", ["4.1.4"])

      expect(dependency_list.to_s).to eq %(gem "rails", "4.1.4")
    end

    it "retains the order of dependencies" do
      dependency_list.add("rails", ["4.1.4"])
      dependency_list.add("bundler", ["1.7.2"])

      expect(dependency_list.to_s).to eq <<-GEMS.strip_heredoc.strip
        gem "rails", "4.1.4"
        gem "bundler", "1.7.2"
      GEMS
    end

    it "overrides dependency with the same name" do
      dependency_list.add("rails", ["4.1.0"])
      dependency_list.add("rails", ["4.1.4"])

      expect(dependency_list.to_s).to eq %(gem "rails", "4.1.4")
    end
  end

  describe "#remove" do
    let(:dependency_list) { Appraisal::DependencyList.new }

    before do
      dependency_list.add("rails", ["4.1.4"])
    end

    it "removes the dependency from the list" do
      dependency_list.remove("rails")
      expect(dependency_list.to_s).to eq("")
    end

    it "respects the removal over an addition" do
      dependency_list.remove("rails")
      dependency_list.add("rails", ["4.1.0"])
      expect(dependency_list.to_s).to eq("")
    end
  end
end

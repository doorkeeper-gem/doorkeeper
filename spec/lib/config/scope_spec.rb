require 'spec_helper_integration'

module Doorkeeper
  describe Scope do
    context 'initialized only with name' do
      subject do
        Scope.new("public")
      end

      it "has a given name" do
        subject.name.should == "public"
      end

      it "has default set to false" do
        subject.default.should be_false
      end

      it "has no description" do
        subject.description.should be_nil
      end
    end

    context 'initialized with options' do
      let :description do
        "Paranoic scope"
      end

      subject do
        Scope.new("write", :default => true, :description => description)
      end

      it "has given name" do
        subject.name.should == "write"
      end

      it "has given value of default" do
        subject.default.should be_true
      end

      it "has given valud of description" do
        subject.description.should == description
      end
    end
  end
end

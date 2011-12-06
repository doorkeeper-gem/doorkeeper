require 'spec_helper'

module Doorkeeper
  describe Scopes do
    before :each do
      if defined? scopes_array
        scopes_array.each do |scope|
          subject.add scope
        end
      end
    end

    let :scope do
      scope_double("public", false)
    end

    describe :add do
      it 'allows you to add scopes' do
        subject.add scope
        subject.all.should == [scope]
      end

      it 'raises error if you try to add illegal element' do
        expect do
          subject.add double
        end.to raise_error Doorkeeper::Scopes::IllegalElement
      end
    end

    describe :[] do
      let :public_scope do
        scope_double("public", false)
      end

      let :write_scope do
        scope_double("write", false)
      end

      subject do
        Scopes.new.tap do |scopes|
          scopes.add public_scope
          scopes.add write_scope
        end
      end

      it 'returns the scope with given name' do
        subject[:public].should == public_scope
        subject[:write].should == write_scope
      end

      it 'returns nil if there does not exist scope with given name' do
        subject[:awesome].should be_nil
      end
    end

    describe :all do
      let :scopes_array do
        create_scopes_array "scope1", true,
                            "scope2", false,
                            "scope3", true
      end

      it "returns all added scopes" do
        subject.all.should == scopes_array
      end
    end

    describe :defaults do
      let :default_scopes do
        create_scopes_array "public", true,
                            "other_public", true
      end

      let :scopes_array do
        array = create_scopes_array "awesome", false,
                                    "awesome2", false
        array + default_scopes
      end

      it "returns scopes with a default flag" do
        subject.defaults.should == default_scopes
      end
    end

    describe :with_names do
      let :scopes_array do
        create_scopes_array "scope1", true,
                            "scope2", false,
                            "scope3", false

      end

      it "returns array of scopes with given names" do
        returned_scopes = subject.with_names("scope1", "scope3")
        returned_scopes.should have(2).items
        returned_scopes.map(&:name).should include("scope1", "scope3")

      end
    end

    describe :default_scope_string do
      let :default_scopes do
        create_scopes_array "public", true,
                            "other_public", true
      end

      let :scopes_array do
        array = create_scopes_array "awesome", false,
                                    "awesome2", false
        array + default_scopes
      end

      it "returns the string that joins names of default scopes" do
        subject.default_scope_string.should == "public other_public"
      end

    end

    def create_scopes_array(*args)
      args.each_slice(2).map do |slice|
        scope_double(*slice)
      end
    end

    def scope_double(name, default)
      double(name, :name => name, :default => default)
    end
  end
end

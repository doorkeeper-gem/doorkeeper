require 'spec_helper'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/string'
require 'doorkeeper/config/scopes'
require 'doorkeeper/config/scope'

module Doorkeeper
  describe Scopes do
    before :each do
      if defined? scopes_array
        scopes_array.each do |scope|
          subject.add scope
        end
      end
    end

    describe :add do
      it 'allows you to add scopes' do
        scope = create_scope "public", false
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
        create_scope "public", false
      end

      let :write_scope do
        create_scope "write", false
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

    describe :exists? do
      subject do
        Scopes.new.tap do |scopes|
          scopes.add create_scope "public", false
        end
      end

      it 'returns true if scope with given name is present' do
        subject.exists?("public").should be_true
      end

      it 'returns false if scope with given name does not exist' do
        subject.exists?("other").should be_false
      end

      it 'handles symbols' do
        subject.exists?(:public).should be_true
        subject.exists?(:other).should be_false
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

    describe :all_included? do
      subject do
        Scopes.new.tap do |s|
          s.add create_scope("public", true)
          s.add create_scope("write", false)
        end
      end

      it "is true if any scopes is included" do
        subject.all_included?("public").should be_true
      end

      it "is true if all scopes are included" do
        subject.all_included?("public write").should be_true
      end

      it "is true if all scopes are included in any order" do
        subject.all_included?("write public").should be_true
      end

      it "is false if no scopes are included" do
        subject.all_included?("notexistent").should be_false
      end

      it "is false if no scopes are included even for existing ones" do
        subject.all_included?("public write notexistent").should be_false
      end
    end

    def create_scopes_array(*args)
      args.each_slice(2).map do |slice|
        create_scope(*slice)
      end
    end

    def create_scope(name, default)
      Scope.new(name, :default => default)
    end
  end
end

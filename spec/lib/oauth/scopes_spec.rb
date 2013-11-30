require 'spec_helper'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/scopes'

module Doorkeeper::OAuth
  describe Scopes do
    describe :add do
      it 'allows you to add scopes with symbols' do
        subject.add :public
        subject.all.should == ['public']
      end

      it 'allows you to add scopes with strings' do
        subject.add "public"
        subject.all.should == ['public']
      end

      it 'do not add already included scopes' do
        subject.add :public
        subject.add :public
        subject.all.should == ['public']
      end
    end

    describe :exists do
      before do
        subject.add :public
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

    describe ".from_string" do
      let(:string) { "public write" }

      subject { Scopes.from_string(string) }

      it { should be_a(Scopes) }
      its(:all) { should == ['public', 'write'] }
    end

    describe :+ do
      it "can add to another scope object" do
        scopes = Scopes.from_string("public") + Scopes.from_string("admin")
        scopes.all.should == ['public', 'admin']
      end

      it "does not change the existing object" do
        origin = Scopes.from_string("public")
        new_scope = origin + Scopes.from_string("admin")
        origin.to_s.should == "public"
      end

      it "raises an error if cannot handle addition" do
        expect {
          Scopes.from_string("public") + "admin"
        }.to raise_error(NoMethodError)
      end
    end

    describe :== do
      it 'is equal to another set of scopes' do
        Scopes.from_string("public").should == Scopes.from_string("public")
      end

      it 'is equal to another set of scopes with no particular order' do
        Scopes.from_string("public write").should == Scopes.from_string("write public")
      end

      it 'differs from another set of scopes when scopes are not the same' do
        Scopes.from_string("public write").should_not == Scopes.from_string("write")
      end
    end

    describe :has_scopes? do
      subject { Scopes.from_string("public admin") }

      it "returns true when at least one scope is included" do
        subject.has_scopes?(Scopes.from_string("public")).should be_true
      end

      it "returns true when all scopes are included" do
        subject.has_scopes?(Scopes.from_string("public admin")).should be_true
      end

      it "is true if all scopes are included in any order" do
        subject.has_scopes?(Scopes.from_string("admin public")).should be_true
      end

      it "is false if no scopes are included" do
        subject.has_scopes?(Scopes.from_string("notexistent")).should be_false
      end

      it "returns false when any scope is not included" do
        subject.has_scopes?(Scopes.from_string("public nope")).should be_false
      end

      it "is false if no scopes are included even for existing ones" do
        subject.has_scopes?(Scopes.from_string("public admin notexistent")).should be_false
      end
    end
  end
end

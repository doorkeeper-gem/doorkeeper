require 'spec_helper_integration'

module Doorkeeper
  describe Config::ScopesBuilder do
    context 'provides DSL to create Scopes collection' do
      subject do
        Config::ScopesBuilder.new do
          scope :public, :default => true, :description => "A"
          scope :write, :description => "B"
        end
      end

      describe :build do
        it 'returns Scopes instance' do
          subject.build.should be_a(Doorkeeper::Scopes)
        end

        it 'contains defined scopes' do
          scopes = subject.build
          scopes.all.should have(2).items
          scopes[:public].description.should == "A"
          scopes[:write].description.should == "B"
        end
      end
    end
  end
end

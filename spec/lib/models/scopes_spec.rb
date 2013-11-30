require 'spec_helper'
require 'active_support/core_ext/module/delegation'
require 'doorkeeper/oauth/scopes'
require 'doorkeeper/models/scopes'

describe 'Doorkeeper::Models::Scopes' do
  subject do
    Class.new(Hash) do
      include Doorkeeper::Models::Scopes
    end.new
  end

  before do
    subject[:scopes] = 'public admin'
  end

  describe :scopes do
    it 'is a `Scopes` class' do
      subject.scopes.should be_a(Doorkeeper::OAuth::Scopes)
    end

    it 'includes scopes' do
      subject.scopes.should include('public')
    end
  end

  describe :scopes_string do
    it 'is a `Scopes` class' do
      subject.scopes_string.should == 'public admin'
    end
  end
end

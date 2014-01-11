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
      expect(subject.scopes).to be_a(Doorkeeper::OAuth::Scopes)
    end

    it 'includes scopes' do
      expect(subject.scopes).to include('public')
    end
  end

  describe :scopes_string do
    it 'is a `Scopes` class' do
      expect(subject.scopes_string).to eq('public admin')
    end
  end
end

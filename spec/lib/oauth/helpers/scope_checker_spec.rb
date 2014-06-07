require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/helpers/scope_checker'
require 'doorkeeper/oauth/scopes'

module Doorkeeper::OAuth::Helpers
  describe ScopeChecker, '.matches?' do
    def new_scope(*args)
      Doorkeeper::OAuth::Scopes.from_array args
    end

    it 'true if scopes matches' do
      scopes = new_scope :public
      scopes_to_match = new_scope :public
      expect(ScopeChecker.matches?(scopes, scopes_to_match)).to be_truthy
    end

    it 'is false when scopes differs' do
      scopes = new_scope :public
      scopes_to_match = new_scope :write
      expect(ScopeChecker.matches?(scopes, scopes_to_match)).to be_falsey
    end

    it 'is false when scope in array is missing' do
      scopes = new_scope :public
      scopes_to_match = new_scope :public, :write
      expect(ScopeChecker.matches?(scopes, scopes_to_match)).to be_falsey
    end

    it 'is false when scope in string is missing' do
      scopes = new_scope :public, :write
      scopes_to_match = new_scope :public
      expect(ScopeChecker.matches?(scopes, scopes_to_match)).to be_falsey
    end

    it 'is false when any of attributes is nil' do
      expect(ScopeChecker.matches?(nil, double)).to be_falsey
      expect(ScopeChecker.matches?(double, nil)).to be_falsey
    end
  end

  describe ScopeChecker, '.valid?' do
    let(:server_scopes) { Doorkeeper::OAuth::Scopes.new }

    it 'is valid if scope is present' do
      server_scopes.add :scope
      expect(ScopeChecker.valid?('scope', server_scopes)).to be_truthy
    end

    it 'is invalid if includes tabs space' do
      expect(ScopeChecker.valid?("\tsomething", server_scopes)).to be_falsey
    end

    it 'is invalid if scope is not present' do
      expect(ScopeChecker.valid?(nil, server_scopes)).to be_falsey
    end

    it 'is invalid if scope is blank' do
      expect(ScopeChecker.valid?(' ', server_scopes)).to be_falsey
    end

    it 'is invalid if includes return space' do
      expect(ScopeChecker.valid?("scope\r", server_scopes)).to be_falsey
    end

    it 'is invalid if includes new lines' do
      expect(ScopeChecker.valid?("scope\nanother", server_scopes)).to be_falsey
    end

    it 'is invalid if any scope is not included in server scopes' do
      expect(ScopeChecker.valid?('scope another', server_scopes)).to be_falsey
    end
  end
end

require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/helpers/scope_checker'
require 'doorkeeper/oauth/scopes'

module Doorkeeper::OAuth::Helpers
  describe ScopeChecker, ".matches?" do
    def new_scope(*args)
      Doorkeeper::OAuth::Scopes.from_array args
    end

    it "true if scopes matches" do
      scopes = new_scope :public
      scopes_to_match = new_scope :public
      ScopeChecker.matches?(scopes, scopes_to_match).should be_true
    end

    it "is false when scopes differs" do
      scopes = new_scope :public
      scopes_to_match = new_scope :write
      ScopeChecker.matches?(scopes, scopes_to_match).should be_false
    end

    it "is false when scope in array is missing" do
      scopes = new_scope :public
      scopes_to_match = new_scope :public, :write
      ScopeChecker.matches?(scopes, scopes_to_match).should be_false
    end

    it "is false when scope in string is missing" do
      scopes = new_scope :public, :write
      scopes_to_match = new_scope :public
      ScopeChecker.matches?(scopes, scopes_to_match).should be_false
    end

    it "is false when any of attributes is nil" do
      ScopeChecker.matches?(nil, stub).should be_false
      ScopeChecker.matches?(stub, nil).should be_false
    end
  end

  describe ScopeChecker, ".valid?" do
    let(:server_scopes) { Doorkeeper::OAuth::Scopes.new }

    it "is valid if scope is present" do
      server_scopes.add :scope
      ScopeChecker.valid?("scope", server_scopes).should be_true
    end

    it "is invalid if includes tabs space" do
      ScopeChecker.valid?("\tsomething", server_scopes).should be_false
    end

    it "is invalid if scope is not present" do
      ScopeChecker.valid?(nil, server_scopes).should be_false
    end

    it "is invalid if scope is blank" do
      ScopeChecker.valid?(" ", server_scopes).should be_false
    end

    it "is invalid if includes return space" do
      ScopeChecker.valid?("scope\r", server_scopes).should be_false
    end

    it "is invalid if includes new lines" do
      ScopeChecker.valid?("scope\nanother", server_scopes).should be_false
    end

    it "is invalid if any scope is not included in server scopes" do
      ScopeChecker.valid?("scope another", server_scopes).should be_false
    end
  end
end

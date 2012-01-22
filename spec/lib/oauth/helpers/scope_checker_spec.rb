require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/helpers/scope_checker'

module Doorkeeper::OAuth::Helpers
  describe ScopeChecker, ".matches?" do
    it "true if scopes matches" do
      scopes = [:public]
      scopes_to_match = "public"
      ScopeChecker.matches?(scopes, scopes_to_match).should be_true
    end

    it "is false when scopes differs" do
      scopes = [:public]
      scopes_to_match = "write"
      ScopeChecker.matches?(scopes, scopes_to_match).should be_false
    end

    it "is false when scope in array is missing" do
      scopes = [:public]
      scopes_to_match = "public write"
      ScopeChecker.matches?(scopes, scopes_to_match).should be_false
    end

    it "is false when scope in string is missing" do
      scopes = [:public, :write]
      scopes_to_match = "public"
      ScopeChecker.matches?(scopes, scopes_to_match).should be_false
    end

    it "is false when any of attributes is nil" do
      ScopeChecker.matches?(nil, stub).should be_false
      ScopeChecker.matches?(stub, nil).should be_false
    end
  end

  describe ScopeChecker, ".valid?" do
    let(:server_scopes) { double :all_included? => true }

    it "is valid if scope is present" do
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
      server_scopes.stub(:all_included?).and_return(false)
      ScopeChecker.valid?("scope another", server_scopes).should be_false
    end
  end
end

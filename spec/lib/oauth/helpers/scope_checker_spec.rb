require 'spec_helper'
require 'doorkeeper/oauth/helpers/scope_checker'

module Doorkeeper::OAuth::Helpers
  describe ScopeChecker do
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
end

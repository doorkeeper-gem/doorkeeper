require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/helpers/scope_checker'
require 'doorkeeper/oauth/scopes'

module Doorkeeper::OAuth::Helpers
  describe ScopeChecker, '.valid?' do
    let(:server_scopes) { Doorkeeper::OAuth::Scopes.new }

    context 'without application scopes' do
      it 'is invalid if scope is present' do
        server_scopes.add :scope
        expect(ScopeChecker.valid?('scope', server_scopes)).to be_falsey
      end

      it 'is invalid if scope is not present' do
        expect(ScopeChecker.valid?(nil, server_scopes)).to be_falsey
      end
    end

    context 'with application_scopes' do
      let(:server_scopes) do
        Doorkeeper::OAuth::Scopes.from_string 'common svr user'
      end
      let(:application_scopes) do
        Doorkeeper::OAuth::Scopes.from_string 'common user extra'
      end

      it 'is invalid if scope is not present' do
        expect(ScopeChecker.valid?(
          nil,
          server_scopes,
          application_scopes
        )).to be_falsey
      end

      it 'is invalid if scope is blank' do
        expect(ScopeChecker.valid?(
          ' ',
          server_scopes,
          application_scopes
        )).to be_falsey
      end

      it 'is invalid if includes tabs space' do
        expect(ScopeChecker.valid?(
          "common\tuser",
          server_scopes,
          application_scopes
        )).to be_falsey
      end

      it 'is invalid if includes return space' do
        expect(ScopeChecker.valid?(
          "common\ruser",
          server_scopes,
          application_scopes
        )).to be_falsey
      end

      it 'is invalid if includes new lines' do
        expect(ScopeChecker.valid?(
          "common\nuser",
          server_scopes
        )).to be_falsey
      end

      it 'is invalid if any scope is not included in server scopes' do
        expect(ScopeChecker.valid?(
          'common extra',
          server_scopes,
          application_scopes
        )).to be_falsey
      end

      it 'is valid if scopes included in the server and the application' do
        expect(ScopeChecker.valid?(
          'common user',
          server_scopes,
          application_scopes
        )).to be_truthy
      end

      it 'is invalid if any scope is not included in the application' do
        expect(ScopeChecker.valid?(
          'svr',
          server_scopes,
          application_scopes
        )).to be_falsey
      end
    end
  end
end

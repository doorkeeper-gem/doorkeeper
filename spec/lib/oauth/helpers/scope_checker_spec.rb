require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/helpers/scope_checker'
require 'doorkeeper/oauth/scopes'

module Doorkeeper::OAuth::Helpers
  describe ScopeChecker, '.valid?' do
    let(:server) do
      server = Object.new
      server.stub(:default_scopes) do
        ::Doorkeeper::OAuth::Scopes.from_string 'common basic'
      end
      server.stub(:scopes) do
        ::Doorkeeper::OAuth::Scopes.from_string 'common basic extra user'
      end
      server
    end

    context 'without application' do
      it 'is invalid if scope is not present' do
        expect(ScopeChecker.valid?(nil, server)).to be_falsey
      end

      it 'is invalid if unknown scope is present' do
        expect(ScopeChecker.valid?('scope', server)).to be_falsey
      end

      it 'is invalid if scope is blank' do
        expect(ScopeChecker.valid?(' ', server)).to be_falsey
      end

      it 'is invalid if includes tabs space' do
        expect(ScopeChecker.valid?("common\tbasic", server)).to be_falsey
      end

      it 'is invalid if includes return space' do
        expect(ScopeChecker.valid?("common\rbasic", server)).to be_falsey
      end

      it 'is invalid if includes new lines' do
        expect(ScopeChecker.valid?("common\nbasic", server)).to be_falsey
      end

      it 'is valid if the scope is in the default set' do
        expect(ScopeChecker.valid?('basic', server)).to be_truthy
      end

      it 'is valid with multiple scopes in the default set' do
        expect(ScopeChecker.valid?('basic common', server)).to be_truthy
      end

      it 'is invalid if the scope is not in the default set' do
        expect(ScopeChecker.valid?('extra', server)).to be_falsey
      end

      it 'is invalid with multiple scopes if any is not in the default set' do
        expect(ScopeChecker.valid?('basic extra common', server)).to be_falsey
      end
    end

    context 'with application' do
      context 'without scopes' do
        let(:application) do
          application = Object.new
          application.stub(:scopes) { nil }
          application
        end

        it 'is invalid if scope is not present' do
          expect(
            ScopeChecker.valid?(nil, server, application)
          ).to be_falsey
        end

        it 'is invalid if unknown scope is present' do
          expect(
            ScopeChecker.valid?('scope', server, application)
          ).to be_falsey
        end

        it 'is invalid if scope is blank' do
          expect(
            ScopeChecker.valid?(' ', server, application)
          ).to be_falsey
        end

        it 'is invalid if includes tabs space' do
          expect(
            ScopeChecker.valid?("common\tuser", server, application)
          ).to be_falsey
        end

        it 'is invalid if includes return space' do
          expect(
            ScopeChecker.valid?("common\ruser", server, application)
          ).to be_falsey
        end

        it 'is invalid if includes new lines' do
          expect(
            ScopeChecker.valid?("common\nuser", server, application)
          ).to be_falsey
        end

        it 'is valid if the scope is in the full set of server scopes' do
          expect(
            ScopeChecker.valid?('common extra user', server, application)
          ).to be_truthy
        end

        it 'is invalid if any scope is not in the full set of server scopes' do
          expect(
            ScopeChecker.valid?(
              'common extra user invalid',
              server,
              application)
          ).to be_falsey
        end
      end

      context 'with scopes' do
        let(:application) do
          application = Object.new
          application.stub(:scopes) do
            Doorkeeper::OAuth::Scopes.from_string 'common user extra'
          end
          application
        end

        it 'is valid if the scope is in the server/app intersection' do
          expect(
            ScopeChecker.valid?('common', server, application)
          ).to be_truthy
        end

        it 'is valid with multiple scopes in the server/app intersection' do
          expect(
            ScopeChecker.valid?('common extra user', server, application)
          ).to be_truthy
        end

        it 'is invalid if the scope is not in the application set' do
          expect(
            ScopeChecker.valid?('basic', server, application)
          ).to be_falsey
        end

        it 'is invalid if any scope not in the application set' do
          expect(
            ScopeChecker.valid?('extra common user basic', server, application)
          ).to be_falsey
        end

        it 'is invalid if the scope is not in the server set' do
          expect(
            ScopeChecker.valid?('invalid', server, application)
          ).to be_falsey
        end

        it 'is invalid if any scope is not included in server scopes' do
          expect(
            ScopeChecker.valid?('extra common invalid', server, application)
          ).to be_falsey
        end
      end
    end
  end
end

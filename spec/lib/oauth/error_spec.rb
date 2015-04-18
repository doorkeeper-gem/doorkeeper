require 'spec_helper'
require 'active_support/i18n'
require 'doorkeeper/oauth/error'

module Doorkeeper::OAuth
  describe Error do
    subject { Error.new(:some_error, :some_state) }

    it { should respond_to(:name) }
    it { should respond_to(:state) }

    describe :description do
      it 'is translated from translation messages' do
        expect(I18n).to receive(:translate).with(:some_error, scope: [:doorkeeper, :errors, :messages])
        subject.description
      end
    end
  end
end

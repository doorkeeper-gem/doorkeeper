require 'spec_helper'
require 'active_model'
require 'doorkeeper/oauth/error'
require 'doorkeeper/oauth/error_response'

module Doorkeeper::OAuth
  describe ErrorResponse do
    describe '#status' do
      it 'should have a status of unauthorized' do
        expect(subject.status).to eq(:unauthorized)
      end
    end

    describe :from_request do
      it 'has the error from request' do
        error = ErrorResponse.from_request double(error: :some_error)
        expect(error.name).to eq(:some_error)
      end

      it 'ignores state if request does not respond to state' do
        error = ErrorResponse.from_request double(error: :some_error)
        expect(error.state).to be_nil
      end

      it 'has state if request responds to state' do
        error = ErrorResponse.from_request double(error: :some_error, state: :hello)
        expect(error.state).to eq(:hello)
      end
    end

    it 'ignores empty error values' do
      subject = ErrorResponse.new(error: :some_error, state: nil)
      expect(subject.body).not_to have_key(:state)
    end

    describe '.body' do
      subject { ErrorResponse.new(name: :some_error, state: :some_state).body }

      describe '#body' do
        it { should have_key(:error) }
        it { should have_key(:error_description) }
        it { should have_key(:state) }
      end
    end

    describe '.authenticate_info' do
      let(:error_response) { ErrorResponse.new(name: :some_error, state: :some_state) }
      subject { error_response.authenticate_info }

      it { should include("realm=\"#{error_response.realm}\"") }
      it { should include("error=\"#{error_response.name}\"") }
      it { should include("error_description=\"#{error_response.description}\"") }
    end

    describe '.headers' do
      subject { ErrorResponse.new(name: :some_error, state: :some_state).headers }

      it { should include 'WWW-Authenticate' }
    end
  end
end

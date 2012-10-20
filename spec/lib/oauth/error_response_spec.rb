require 'spec_helper'
require 'active_model'
require 'doorkeeper/oauth/error'
require 'doorkeeper/oauth/error_response'

module Doorkeeper::OAuth
  describe ErrorResponse do
    its(:status) { should == :unauthorized }

    describe :from_request do
      it 'has the error from request' do
        error = ErrorResponse.from_request stub(:error => :some_error)
        error.name.should == :some_error
      end

      it 'ignores state if request does not respond to state' do
        error = ErrorResponse.from_request stub(:error => :some_error)
        error.state.should be_nil
      end

      it 'has state if request responds to state' do
        error = ErrorResponse.from_request stub(:error => :some_error, :state => :hello)
        error.state.should == :hello
      end
    end

    it 'ignores empty error values' do
      subject = ErrorResponse.new(:error => :some_error, :state => nil)
      subject.body.should_not have_key(:state)
    end

    describe '.body' do
      subject { ErrorResponse.new(:name => :some_error, :state => :some_state) }

      its(:body) { should have_key(:error) }
      its(:body) { should have_key(:error_description) }
      its(:body) { should have_key(:state) }
    end
  end
end

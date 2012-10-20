require 'spec_helper'
require 'active_support/all'
require 'doorkeeper/errors'
require 'doorkeeper/server'

describe Doorkeeper::Server do
  let(:fake_class) { mock :fake_class }

  subject do
    described_class.new
  end

  describe '.strategy_for' do
    it 'returns existing strategy' do
      stub_const 'Doorkeeper::Request::Code', fake_class
      subject.strategy_for(:code).should == Doorkeeper::Request::Code
    end

    it 'raises error when strategy does not exist' do
      expect { subject.strategy_for(:duh) }.to raise_error(Doorkeeper::Errors::InvalidRequestStrategy)
    end
  end

  describe '.request' do
    it 'builds the request with selected strategy' do
      stub_const 'Doorkeeper::Request::Code', fake_class
      fake_class.should_receive(:build).with(subject)
      subject.request :code
    end
  end
end

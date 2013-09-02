require 'spec_helper'
require 'active_support/all'
require 'doorkeeper/errors'
require 'doorkeeper/server'

describe Doorkeeper::Server do
  let(:fake_class) { mock :fake_class }

  subject do
    described_class.new
  end

  describe '.authorization_request' do
    it 'raises error when strategy does not exist' do
      expect { subject.authorization_request(:duh) }.to raise_error(Doorkeeper::Errors::InvalidAuthorizationStrategy)
    end

    it 'raises error when strategy does not match phase' do
      expect { subject.token_request(:code) }.to raise_error(Doorkeeper::Errors::InvalidTokenStrategy)
    end

    it 'builds the request with selected strategy' do
      stub_const 'Doorkeeper::Request::Code', fake_class
      fake_class.should_receive(:build).with(subject)
      subject.authorization_request :code
    end
  end
end

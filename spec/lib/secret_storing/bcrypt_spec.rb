# frozen_string_literal: true

require 'spec_helper'
require 'bcrypt'

describe ::Doorkeeper::SecretStoring::BCrypt do
  subject { described_class }
  let(:instance) { double('instance', token: 'foo') }

  describe '#transform_secret' do
    it 'creates a bcrypt password' do
      expect(subject.transform_secret('foo')).to be_a BCrypt::Password
    end
  end

  describe '#restore_secret' do
    it 'raises' do
      expect { subject.restore_secret(instance, :token) }.to raise_error(NotImplementedError)
    end
  end

  describe '#allows_restoring_secrets?' do
    it 'does not allow it' do
      expect(subject.allows_restoring_secrets?).to eq false
    end
  end

  describe 'validate_for' do
    it 'allows for valid model' do
      expect(subject.validate_for(:application)).to eq true
    end

    it 'raises for invalid model' do
      expect { subject.validate_for(:wat) }
        .to raise_error(ArgumentError, /can only be used for storing application secrets/)
      expect { subject.validate_for(:token) }
        .to raise_error(ArgumentError, /can only be used for storing application secrets/)
    end
  end

  describe 'secret_matches?' do
    it 'compares input with #transform_secret' do
      expect(subject.secret_matches?('input', 'input')).to eq false

      password = BCrypt::Password.create 'foobar'
      expect(subject.secret_matches?('foobar', password.to_s)).to eq true
    end
  end
end

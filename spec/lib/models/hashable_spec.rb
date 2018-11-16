# frozen_string_literal: true

require 'spec_helper'

describe 'Hashable' do
  let(:clazz) do
    Class.new do
      include Doorkeeper::Models::Hashable

      def self.find_by(*)
        raise 'stub this'
      end

      def update_column(*)
        raise 'stub this'
      end

      def token
        raise 'stub this'
      end
    end
  end

  describe :hashed_or_plain_token do
    let(:enabled_hashing?) { false }
    subject { clazz.send(:hashed_or_plain_token, 'input') }

    before do
      allow(clazz).to receive(:perform_secret_hashing?)
        .and_return enabled_hashing?
    end

    context 'when no hash function set' do
      it 'returns the plain input' do
        expect(subject).to eq 'input'
      end

      context 'when hashing enabled' do
        let(:enabled_hashing?) { true }

        it 'uses the default function' do
          expect(clazz)
            .to receive(:default_hash_function)
            .with('input')
            .and_call_original

          expect(subject).not_to eq 'input'
        end
      end
    end

    context 'when hash_function defined' do
      let(:hash_function) { ->(input) { input + '-hashed' } }

      before do
        clazz.secret_hash_function = hash_function
      end

      it 'returns the plain input' do
        expect(clazz).not_to receive(:default_hash_function)
        expect(subject).to eq 'input'
      end

      context 'when hashing enabled' do
        let(:enabled_hashing?) { true }

        it 'uses that function' do
          expect(hash_function)
            .to receive(:call)
            .with('input')
            .and_call_original

          expect(subject).to eq 'input-hashed'
        end
      end
    end
  end

  describe :secret_matches? do
    context 'when comparer undefined' do
      it 'uses a default compare' do
        expect(clazz).to receive(:default_comparer).with('a', 'a').and_return true
        expect(clazz.secret_matches?('a', 'a')).to be_truthy
      end
    end

    context 'when comparer defined' do
      let(:comparer) do
        ->(*) { false }
      end

      before do
        clazz.secret_comparer = comparer
      end

      it 'uses that comparer' do
        expect(comparer).to receive(:call).with('a', 'a').and_call_original
        expect(clazz.secret_matches?('a', 'a')).to be_falsey
      end
    end
  end

  describe :find_by_fallback_token do
    let(:old_token) { instance_double(clazz, token: 'input') }
    subject { clazz.send(:find_by_fallback_token, :token, 'input') }

    it 'does not call find_by when not configured' do
      expect(clazz).not_to receive(:find_by)
      expect(subject).to eq(nil)
    end

    context 'when fallback configured' do
      include_context 'with token hashing and fallback lookup enabled'
      let(:hashed_token) { hashed_or_plain_token_func.call('input') }

      it 'upgrades the plain token if no hashed exists' do
        expect(clazz).to receive(:find_by).with(token: 'input').and_return(old_token)
        expect(old_token).to receive(:update_column).with(:token, hashed_token)

        expect(subject).to eq(old_token)
      end
    end
  end

  describe :find_by_plaintext_token do
    let(:plain_token) { 'asdf' }
    let(:subject) { clazz.send(:find_by_plaintext_token, :token, plain_token) }
    let(:hashing_enabled?) { false }

    before do
      allow(clazz).to receive(:perform_secret_hashing?).and_return(hashing_enabled?)
    end

    context 'when not configured' do
      it 'always finds with the plain value even when nil' do
        expect(clazz).to receive(:find_by).with(token: plain_token).once.and_return(nil)
        expect(subject).to eq(nil)
      end
    end

    context 'when hashing configured' do
      let(:hashing_enabled?) { true }
      let(:hashed_token) { clazz.send(:default_hash_function, plain_token) }

      it 'calls find_by only on the hashed value if it returns' do
        expect(clazz).not_to receive(:find_by).with(token: plain_token)
        expect(clazz).to receive(:find_by).with(token: hashed_token).and_return(:result)

        expect(subject).to eq(:result)
      end

      it 'does not fall back to plain token' do
        expect(clazz).not_to receive(:find_by).with(token: plain_token)
        expect(clazz).to receive(:find_by).with(token: hashed_token).and_return(nil)

        expect(subject).to eq(nil)
      end

      context 'when fallback configured' do
        let(:old_token) { instance_double(clazz, token: plain_token) }
        let(:hashed_token) { hashed_or_plain_token_func.call(plain_token) }

        include_context 'with token hashing and fallback lookup enabled'

        it 'does not fallback if found by hashed token' do
          expect(clazz).to receive(:find_by).with(token: hashed_token).and_return old_token
          expect(clazz).not_to receive(:find_by).with(token: plain_token)
          expect(clazz).not_to receive(:upgrade_fallback_value)

          expect(subject).to eq(old_token)
        end

        it 'also searches for the plain token if no hashed exists' do
          expect(clazz).to receive(:find_by).with(token: hashed_token).and_return nil
          expect(clazz).to receive(:find_by).with(token: plain_token).and_return(old_token)
          expect(old_token).to receive(:update_column).with(:token, hashed_token)

          expect(subject).to eq(old_token)
        end
      end
    end
  end
end

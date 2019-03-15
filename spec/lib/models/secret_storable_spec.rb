# frozen_string_literal: true

require 'spec_helper'

describe 'SecretStorable' do
  let(:clazz) do
    Class.new do
      include Doorkeeper::Models::SecretStorable

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
  let(:strategy) { clazz.secret_strategy }

  describe :find_by_plaintext_token do
    subject { clazz.send(:find_by_plaintext_token, 'attr', 'input') }

    it 'forwards to the secret_strategy' do
      expect(strategy)
        .to receive(:transform_secret)
        .with('input')
        .and_return 'found'

      expect(clazz)
        .to receive(:find_by)
        .with('attr' => 'found')
        .and_return 'result'


      expect(subject).to eq 'result'
    end

    it 'calls find_by_fallback_token if not found' do
      expect(clazz)
        .to receive(:find_by)
        .with('attr' => 'input')
        .and_return nil

      expect(clazz)
        .to receive(:find_by_fallback_token)
        .with('attr', 'input')
        .and_return 'fallback'

      expect(subject).to eq 'fallback'
    end
  end

  describe :find_by_fallback_token do
    subject { clazz.send(:find_by_fallback_token, 'attr', 'input') }
    let(:fallback) { double(::Doorkeeper::SecretStoring::Plain) }

    it 'returns nil if none defined' do
      expect(clazz.fallback_secret_strategy).to eq nil
      expect(subject).to eq nil
    end

    context 'if a fallback strategy is defined' do
      let(:resource) { double('Token model') }
      before do
        allow(clazz).to receive(:fallback_secret_strategy).and_return(fallback)
      end

      it 'calls the strategy for lookup' do
        expect(clazz)
          .to receive(:find_by)
          .with('attr' => 'fallback')
          .and_return(resource)

        expect(fallback)
          .to receive(:transform_secret)
          .with('input')
          .and_return('fallback')

        # store_secret will call the resource
        expect(resource)
          .to receive(:attr=)
          .with('new value')

        # It will upgrade the secret automtically using the current strategy
        expect(strategy)
          .to receive(:transform_secret)
          .with('input')
          .and_return('new value')

        expect(resource).to receive(:update).with('attr' => 'new value')
        expect(subject).to eq resource
      end
    end
  end


  describe :secret_strategy do
    it 'defaults to plain strategy' do
      expect(strategy).to eq Doorkeeper::SecretStoring::Plain
    end
  end

  describe :fallback_secret_strategy do
    it 'defaults to nil' do
      expect(clazz.fallback_secret_strategy).to eq nil
    end
  end
end

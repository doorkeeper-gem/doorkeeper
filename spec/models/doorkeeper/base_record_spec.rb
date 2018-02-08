# frozen_string_literal: true

require 'spec_helper_integration'

module Doorkeeper
  describe AccessToken do
    describe '.ordered_by' do
      let(:attribute) { 'name' }

      context 'when a direction is not specifed' do
        subject { described_class.ordered_by(attribute) }

        it 'calls order with a default order of desc' do
          expect(described_class).to receive(:order).with(attribute => :asc)
          subject
        end
      end

      context 'when a direction is specifed' do
        subject { described_class.ordered_by(attribute, direction) }

        let(:direction) { 'desc' }

        it 'calls order with the specified direction' do
          expect(described_class).to receive(:order).with(attribute => direction)
          subject
        end
      end
    end
  end
end

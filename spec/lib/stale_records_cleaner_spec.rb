# frozen_string_literal: true

require 'spec_helper'

describe Doorkeeper::StaleRecordsCleaner do
  let(:cleaner) { described_class.new(model) }
  let(:models_by_name) do
    {
      access_token: Doorkeeper::AccessToken,
      access_grant: Doorkeeper::AccessGrant
    }
  end

  %i[access_token access_grant].each do |model_name|
    context "(#{model_name})" do
      let(:model) { models_by_name.fetch(model_name) }

      describe '#clean_revoked' do
        subject { cleaner.clean_revoked }

        context 'with revoked record' do
          before do
            FactoryBot.create model_name, revoked_at: Time.current - 1.minute
          end

          it 'removes the record' do
            expect { subject }.to change { model.count }.to(0)
          end
        end

        context 'with record revoked in the future' do
          before do
            FactoryBot.create model_name, revoked_at: Time.current + 1.minute
          end

          it 'keeps the record' do
            expect { subject }.not_to(change { model.count })
          end
        end

        context 'with unrevoked record' do
          before do
            FactoryBot.create model_name, revoked_at: nil
          end

          it 'keeps the record' do
            expect { subject }.not_to(change { model.count })
          end
        end
      end

      describe '#clean_expired' do
        subject { cleaner.clean_expired(ttl) }
        let(:ttl) { 500 }
        let(:expiry_border) { ttl.seconds.ago }

        context 'with record that is expired' do
          before do
            FactoryBot.create model_name, created_at: expiry_border - 1.minute
          end

          it 'removes the record' do
            expect { subject }.to change { model.count }.to(0)
          end
        end

        context 'with record that is not expired' do
          before do
            FactoryBot.create model_name, created_at: expiry_border + 1.minute
          end

          it 'keeps the record' do
            expect { subject }.not_to(change { model.count })
          end
        end
      end
    end
  end
end

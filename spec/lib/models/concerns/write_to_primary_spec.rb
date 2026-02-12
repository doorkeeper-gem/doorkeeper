# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::Concerns::WriteToPrimary do
  let(:test_class) do
    Class.new do
      include Doorkeeper::Models::Concerns::WriteToPrimary

      def self.create_record
        with_primary_role do
          "created"
        end
      end
    end
  end

  describe ".with_primary_role" do
    context "when ActiveRecord is not defined" do
      let(:original_active_record) { ActiveRecord }

      before do
        Doorkeeper.configure do
          orm :active_record
          enable_multiple_databases
        end

        # Temporarily hide ActiveRecord constant
        stub_const("ActiveRecord", nil)
      end

      after do
        # Restore ActiveRecord for cleanup
        stub_const("ActiveRecord", original_active_record)
      end

      it "executes block without connected_to when ActiveRecord is not available" do
        expect(test_class.create_record).to eq("created")
      end
    end

    context "when enable_multiple_databases is disabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          # enable_multiple_databases is disabled by default
        end
      end

      it "executes block without connected_to" do
        expect(ActiveRecord::Base).not_to receive(:connected_to)
        expect(test_class.create_record).to eq("created")
      end
    end

    context "when enable_multiple_databases is enabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          enable_multiple_databases
        end
      end

      context "when ActiveRecord supports connected_to" do
        before do
          allow(ActiveRecord::Base).to receive(:respond_to?)
            .with(:connected_to)
            .and_return(true)
        end

        it "wraps block in connected_to with writing role" do
          expect(ActiveRecord::Base).to receive(:connected_to)
            .with(role: :writing)
            .and_yield

          expect(test_class.create_record).to eq("created")
        end
      end

      context "when ActiveRecord does not support connected_to" do
        before do
          allow(ActiveRecord::Base).to receive(:respond_to?)
            .with(:connected_to)
            .and_return(false)
        end

        it "executes block without connected_to" do
          expect(ActiveRecord::Base).not_to receive(:connected_to)
          expect(test_class.create_record).to eq("created")
        end
      end
    end
  end
end

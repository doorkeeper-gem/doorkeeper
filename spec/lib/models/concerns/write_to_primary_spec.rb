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
      before(:each) do
        # Override the global before hook by skipping DatabaseCleaner for this context
        # This is needed because removing ActiveRecord causes DatabaseCleaner to fail
      end

      after(:each) do
        # Override the global after hook - don't try to clean database
      end

      around do |example|
        # Save original ActiveRecord
        original_active_record = Object.const_get("ActiveRecord")
        
        begin
          # Temporarily hide ActiveRecord constant
          Object.send(:remove_const, "ActiveRecord")
          
          # Run the test
          Doorkeeper.configure do
            orm :active_record
            enable_multiple_database_roles
          end
          
          example.run
        ensure
          # Restore ActiveRecord for cleanup
          Object.const_set("ActiveRecord", original_active_record)
        end
      end

      it "executes block without connected_to when ActiveRecord is not available" do
        expect(test_class.create_record).to eq("created")
      end
    end

    context "when enable_multiple_database_roles is disabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          # enable_multiple_database_roles is disabled by default
        end
      end

      it "executes block without connected_to" do
        expect(ActiveRecord::Base).not_to receive(:connected_to)
        expect(test_class.create_record).to eq("created")
      end
    end

    context "when enable_multiple_database_roles is enabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          enable_multiple_database_roles
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

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::SecretStorable do
  let(:clazz) do
    Class.new do
      include Doorkeeper::Models::SecretStorable

      def self.find_by(*)
        raise "stub this"
      end

      def update(*)
        raise "stub this"
      end

      def token
        raise "stub this"
      end
    end
  end
  let(:strategy) { clazz.secret_strategy }

  describe ".find_by_plaintext_token" do
    subject(:result) { clazz.send(:find_by_plaintext_token, "attr", "input") }

    it "forwards to the secret_strategy" do
      expect(strategy)
        .to receive(:transform_secret)
        .with("input")
        .and_return "found"

      expect(clazz)
        .to receive(:find_by)
        .with("attr" => "found")
        .and_return "result"

      expect(result).to eq "result"
    end

    it "calls find_by_fallback_token if not found" do
      expect(clazz)
        .to receive(:find_by)
        .with("attr" => "input")
        .and_return nil

      expect(clazz)
        .to receive(:find_by_fallback_token)
        .with("attr", "input")
        .and_return "fallback"

      expect(result).to eq "fallback"
    end
  end

  describe ".find_by_fallback_token" do
    subject(:result) { clazz.send(:find_by_fallback_token, "attr", "input") }

    let(:fallback) { double(::Doorkeeper::SecretStoring::Plain) }

    it "returns nil if none defined" do
      expect(clazz.fallback_secret_strategy).to be_nil
      expect(result).to be_nil
    end

    context "when a fallback strategy is defined" do
      before do
        allow(clazz).to receive(:fallback_secret_strategy).and_return(fallback)
      end

      context "when resource is defined" do
        # A real object rather than a double: what matters is the state the
        # resource is left in, not the messages it received.
        let(:resource) do
          Class.new do
            attr_accessor :attr
            attr_reader :updates

            def initialize
              @attr = "old value"
              @updates = []
            end

            def update(changes)
              @updates << changes
              true
            end
          end.new
        end

        before do
          allow(clazz)
            .to receive(:find_by)
            .with("attr" => "fallback")
            .and_return(resource)

          allow(fallback)
            .to receive(:transform_secret)
            .with("input")
            .and_return("fallback")

          # It will upgrade the secret automatically using the current strategy
          allow(strategy)
            .to receive(:transform_secret)
            .with("input")
            .and_return("new value")
        end

        it "upgrades the stored value through the instance, as it always has" do
          expect(result).to eq resource
          expect(resource.attr).to eq "new value"
          expect(resource.updates).to eq [{ "attr" => "new value" }]
        end

        it "routes the write through the primary database role when the class knows one" do
          roles = []
          clazz.define_singleton_method(:with_primary_role) do |&block|
            roles << :writing
            block.call
          end

          expect(result).to eq resource
          expect(roles).to eq [:writing]
          expect(resource.updates).to eq [{ "attr" => "new value" }]
        end

        # The write itself is an ORM hook, so an ORM able to write
        # conditionally can refuse when the row has moved on from the value
        # the lookup matched.
        context "when the ORM implements the write hook" do
          it "hands the hook the value that matched, read before the upgrade was assigned" do
            received = nil
            clazz.define_singleton_method(:write_upgraded_secret) do |instance, attr, matched, upgraded|
              received = [instance, attr, matched, upgraded]
              true
            end

            expect(result).to eq resource
            expect(received).to eq [resource, "attr", "old value", "new value"]
            expect(resource.attr).to eq "new value"
          end

          it "puts the instance back when the hook answers that nothing was written" do
            clazz.define_singleton_method(:write_upgraded_secret) { |*| false }

            expect(result).to eq resource
            expect(resource.attr).to eq "old value"
          end
        end
      end

      context "when resource is not defined" do
        before do
          allow(clazz).to receive(:fallback_secret_strategy).and_return(fallback)
        end

        it "returns nil" do
          expect(clazz)
            .to receive(:find_by)
            .with("attr" => "fallback")
            .and_return(nil)

          expect(fallback)
            .to receive(:transform_secret)
            .with("input")
            .and_return("fallback")

          # It does not find a token even with the fallback method
          expect(result).to be_nil
        end
      end
    end
  end

  describe ".secret_strategy" do
    it "defaults to plain strategy" do
      expect(strategy).to eq Doorkeeper::SecretStoring::Plain
    end
  end

  describe ".fallback_secret_strategy" do
    it "defaults to nil" do
      expect(clazz.fallback_secret_strategy).to be_nil
    end
  end
end

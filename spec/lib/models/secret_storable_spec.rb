# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::SecretStorable do
  let(:clazz) do
    Class.new do
      include Doorkeeper::Models::SecretStorable

      def self.find_by(*)
        raise "stub this"
      end

      def self.where(*)
        raise "stub this"
      end

      def update_column(*)
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
            attr_reader :cleared_changes

            def initialize
              @attr = "old value"
              @cleared_changes = []
            end

            def id
              1
            end

            def clear_attribute_changes(attr_names)
              @cleared_changes.concat(attr_names.map(&:to_s))
            end
          end.new
        end
        let(:scope) { double("Relation") }

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

        # The stubs are narrow: an upgrade written with anything other than the
        # value that matched falls through to the class, which raises.
        it "upgrades the stored value while the row still holds the matched one" do
          allow(clazz).to receive(:where).with(id: 1, "attr" => "old value").and_return(scope)
          allow(scope).to receive(:update_all).with({ "attr" => "new value" }).and_return(1)

          expect(result).to eq resource
          expect(resource.attr).to eq "new value"
          expect(resource.cleared_changes).to eq %w[attr]
        end

        it "leaves the resource as it was when the row no longer holds the matched value" do
          allow(clazz).to receive(:where).and_return(scope)
          allow(scope).to receive(:update_all).and_return(0)

          expect(result).to eq resource
          expect(resource.attr).to eq "old value"
          expect(resource.cleared_changes).to be_empty
        end
      end

      # This concern is included by the ORM extensions too, so the upgrade may
      # only use what every ORM provides: a Sequel dataset spells `update_all`
      # `update`, and its records have no Active Record dirty tracking to put
      # back in step.
      context "when the ORM provides neither update_all nor dirty tracking" do
        let(:resource) do
          Class.new do
            attr_accessor :attr

            def initialize
              @attr = "old value"
            end

            def id
              1
            end
          end.new
        end
        let(:scope) { double("Dataset") }

        before do
          allow(clazz).to receive(:find_by).with("attr" => "fallback").and_return(resource)
          allow(fallback).to receive(:transform_secret).with("input").and_return("fallback")
          allow(strategy).to receive(:transform_secret).with("input").and_return("new value")
          allow(clazz).to receive(:where).with(id: 1, "attr" => "old value").and_return(scope)
        end

        it "upgrades the stored value through the write the ORM does provide" do
          allow(scope).to receive(:update).with({ "attr" => "new value" }).and_return(1)

          expect(result).to eq resource
          expect(resource.attr).to eq "new value"
        end

        it "leaves the resource as it was when the row no longer holds the matched value" do
          allow(scope).to receive(:update).and_return(0)

          expect(result).to eq resource
          expect(resource.attr).to eq "old value"
        end
      end

      # Row identity is the model's configured primary key, which need not
      # be `id` — and need not exist as a notion at all.
      context "when the ORM names its primary key" do
        let(:resource) do
          Class.new do
            attr_accessor :attr

            def initialize
              @attr = "old value"
            end

            def code
              "app-1"
            end
          end.new
        end
        let(:scope) { double("Relation") }

        before do
          allow(clazz).to receive(:primary_key).and_return("code")
          allow(clazz).to receive(:find_by).with("attr" => "fallback").and_return(resource)
          allow(fallback).to receive(:transform_secret).with("input").and_return("fallback")
          allow(strategy).to receive(:transform_secret).with("input").and_return("new value")
        end

        it "identifies the row by that key" do
          allow(clazz).to receive(:where).with("code" => "app-1", "attr" => "old value").and_return(scope)
          allow(scope).to receive(:update_all).with({ "attr" => "new value" }).and_return(1)

          expect(result).to eq resource
          expect(resource.attr).to eq "new value"
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

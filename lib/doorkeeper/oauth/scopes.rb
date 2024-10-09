# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Scopes
      include Enumerable
      include Comparable

      DYNAMIC_SCOPE_WILDCARD = "*"

      def self.from_string(string)
        string ||= ""
        new.tap do |scope|
          scope.add(*string.split)
        end
      end

      def self.from_array(array)
        new.tap do |scope|
          scope.add(*array)
        end
      end

      delegate :each, :empty?, to: :@scopes

      def initialize
        @scopes = []
      end

      def exists?(scope)
        scope = scope.to_s

        @scopes.any? do |allowed_scope|
          if dynamic_scopes_enabled? && dynamic_scopes_present?(allowed_scope, scope)
            dynamic_scope_match?(allowed_scope, scope)
          else
            allowed_scope == scope
          end
        end
      end

      def add(*scopes)
        @scopes.push(*scopes.map(&:to_s))
        @scopes.uniq!
      end

      def all
        @scopes
      end

      def to_s
        @scopes.join(" ")
      end

      def scopes?(scopes)
        scopes.all? { |scope| exists?(scope) }
      end

      alias has_scopes? scopes?

      def +(other)
        self.class.from_array(all + to_array(other))
      end

      def <=>(other)
        if other.respond_to?(:map)
          map(&:to_s).sort <=> other.map(&:to_s).sort
        else
          super
        end
      end

      def &(other)
        self.class.from_array(all & to_array(other))
      end

      private

      def dynamic_scopes_enabled?
        Doorkeeper.config.enable_dynamic_scopes?
      end

      def dynamic_scope_delimiter
        return unless dynamic_scopes_enabled?

        @dynamic_scope_delimiter ||= Doorkeeper.config.dynamic_scopes_delimiter
      end

      def dynamic_scopes_present?(allowed, requested)
        allowed.include?(dynamic_scope_delimiter) && requested.include?(dynamic_scope_delimiter)
      end

      def dynamic_scope_match?(allowed, requested)
        allowed_pattern = allowed.split(dynamic_scope_delimiter, 2)
        request_pattern = requested.split(dynamic_scope_delimiter, 2)

        return false if allowed_pattern[0] != request_pattern[0]
        return false if allowed_pattern[1].blank?
        return false if request_pattern[1].blank?
        return true  if allowed_pattern[1] == DYNAMIC_SCOPE_WILDCARD && allowed_pattern[1].present?

        allowed_pattern[1] == request_pattern[1]
      end

      def to_array(other)
        case other
        when Scopes
          other.all
        else
          other.to_a
        end
      end
    end
  end
end

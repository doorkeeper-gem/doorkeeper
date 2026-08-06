# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Scopes
      include Enumerable
      include Comparable

      DYNAMIC_SCOPE_WILDCARD = "*"

      def self.from_string(string)
        string ||= ""

        # A non-string scope (e.g. `scope[a]=b`, parsed by Rack into a Hash)
        # has no octets to split into tokens. Reject it as a malformed request
        # (RFC 6749 §3.3); at the token endpoint TokensController's rescue_from
        # turns this into invalid_request. Callers that always pass a string
        # (the model layer) never hit this.
        raise Errors::InvalidScopeParameter, "scope must be a String" unless string.is_a?(String)

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

      # DEPRECATED: With dynamic scopes, #allowed should be called because
      # A & B doesn't really make sense with dynamic scopes.
      #
      # For example, if A = user:* and B is user:1, A & B = [].
      # If we modified this method to take dynamic scopes into an account, then order
      # becomes important, and this would violate the principle that A & B = B & A.
      def &(other)
        return allowed(other) if dynamic_scopes_enabled?

        self.class.from_array(all & to_array(other))
      end

      # Returns a set of scopes that are allowed, taking dynamic
      # scopes into account. This instance's scopes is taken as the allowed set,
      # and the passed value is the set to filter.
      #
      # @param other The set of scopes to filter
      def allowed(other)
        filtered_scopes = other.select { |scope| exists?(scope) }
        self.class.from_array(filtered_scopes)
      end

      # Returns the scopes present in both sets, taking dynamic scopes
      # into account: a dynamic scope pattern (e.g. `user:*`) on either
      # side matches the concrete scope (e.g. `user:1`) on the other,
      # and the concrete scope is what ends up in the result. Unlike
      # #allowed, the same scopes are returned regardless of which set is
      # the receiver, though the order may differ: scopes matched from the
      # argument come first, followed by any scope only the receiver
      # contributes (a concrete scope matched by a pattern in the argument).
      #
      # @param other The set of scopes to intersect with
      def common(other)
        other = self.class.from_array(to_array(other))
        matched = other.select { |scope| exists?(scope) } +
                  select { |scope| other.exists?(scope) }
        self.class.from_array(matched)
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

        return true if allowed_pattern[1] == DYNAMIC_SCOPE_WILDCARD

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

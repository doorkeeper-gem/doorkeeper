# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # ListLike is a mixin for the common functionality in both the
    # ResourceIndicator and Scope sets.
    module ListLike
      extend ActiveSupport::Concern
      include Enumerable
      include Comparable

      class_methods do
        def from_string(string)
          string ||= ""
          new.tap do |collection|
            collection.add(*string.split)
          end
        end

        def from_array(array)
          new.tap do |collection|
            collection.add(*array)
          end
        end
      end

      delegate :each, :empty?, to: :@collection

      def initialize
        @collection = []
      end

      def exists?(collection_item)
        @collection.include? collection_item.to_s
      end

      def add(*collection)
        @collection.push(*collection.map(&:to_s))
        @collection.uniq!
      end

      def all
        @collection
      end

      def to_s
        @collection.join(" ")
      end

      def contains_all?(collection)
        collection.all? { |collection_item| exists?(collection_item) }
      end

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
    end
  end
end

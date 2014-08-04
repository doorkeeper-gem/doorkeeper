module Doorkeeper
  module OAuth
    class Error < Struct.new(:name, :state, :description_key)
      def description
        I18n.translate description_key || name,
          scope: [:doorkeeper, :errors, :messages]
      end
    end
  end
end

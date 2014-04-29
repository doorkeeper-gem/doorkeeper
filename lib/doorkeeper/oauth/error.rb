module Doorkeeper
  module OAuth
    class Error < Struct.new(:name, :state)
      def description
        I18n.translate name, scope: [:doorkeeper, :errors, :messages]
      end
    end
  end
end

# frozen_string_literal: true

module Doorkeeper
  module OAuth
    Error = Struct.new(:name, :state, :translate_options) do
      def description
        options = (translate_options || {}).merge(
          scope: %i[doorkeeper errors messages],
          default: :server_error,
        )

        I18n.translate(name, **options)
      end
    end
  end
end

module Doorkeeper
  module Validations
    extend ActiveSupport::Concern

    attr_accessor :error

    def validate
      @error = nil
      self.class.validations.each do |validation|
        break if @error
        @error = send("validate_#{validation}")
      end
    end

    def valid?
      @error.nil?
    end

    module ClassMethods
      def validate(attribute)
        validations << attribute
      end

      def validations
        @validations ||= []
      end
    end
  end
end

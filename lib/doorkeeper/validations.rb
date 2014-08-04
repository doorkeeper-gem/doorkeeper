module Doorkeeper
  module Validations
    extend ActiveSupport::Concern

    attr_accessor :error
    attr_accessor :error_description_key

    def validate
      @error = nil
      self.class.validations.each do |validation_attr, validation_opts|
        break if @error
        unless send("validate_#{validation_attr}")
          @error                 = validation_opts[:error]
          @error_description_key = validation_opts[:error_description_key]
        end
      end
    end

    def valid?
      validate
      @error.nil?
    end

    module ClassMethods
      def validate(attribute, options = {})
        validations << [attribute, options]
      end

      def validations
        @validations ||= []
      end
    end
  end
end

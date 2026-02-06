require 'date'

module Tins
  # A module that provides dummy date functionality for testing purposes.
  #
  # @example Setting a dummy date
  #   Date.dummy = Date.parse('2009-09-09')
  #
  # @example Using a dummy date in a block
  #   Date.dummy Date.parse('2009-09-09') do
  #     # Your code here
  #   end
  module DateDummy
    # The included method is a hook that gets called when this module is
    # included in another class or module.
    #
    # It sets up date freezing functionality by extending the including
    # class/module with special date handling methods. The method modifies the
    # including class/module's singleton class to provide dummy date
    # capabilities.
    #
    # @param modul [Object] the class or module that includes this module
    def self.included(modul)
      class << modul
        alias really_today today

        remove_method :today rescue nil

        # Sets the dummy date value for date freezing functionality.
        #
        # @param value [Date, String] the date value to set as dummy
        def dummy=(value)
          if value.respond_to?(:to_str)
            value = Date.parse(value.to_str)
          elsif value.respond_to?(:to_date)
            value = value.to_date
          end
          @dummy = value
        end

        # The dummy method provides a way to set and temporarily override a
        # dummy value within a block.
        #
        # @param value [Object] the dummy value to set, or nil to get the
        # current dummy value
        # @yield [] yields control to the block if a value is provided
        # @return [Object] the current dummy value if no value parameter was
        # provided
        # @yieldparam value [Object] the dummy value to set within the block
        # @yieldreturn [Object] the result of the block execution
        def dummy(value = nil)
          if value.nil?
            if defined?(@dummy)
              @dummy
            end
          else
            begin
              old_dummy = @dummy
              self.dummy = value
              yield
            ensure
              self.dummy = old_dummy
            end
          end
        end

        # The today method returns the current date. When a dummy date is set,
        # it returns a duplicate of that date. Otherwise, it delegates to the
        # actual today method implementation.
        #
        # @return [Date] the current date or the dummy date if set
        def today
          if dummy
            dummy.dup
          elsif caller.first =~ /`today`/
            really_today
          else
            really_today
          end
        end
      end
      super
    end
  end
end

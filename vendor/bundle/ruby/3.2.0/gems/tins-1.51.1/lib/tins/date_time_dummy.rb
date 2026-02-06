require 'date'

module Tins
  # A module that provides dummy functionality for DateTime class
  #
  # This module allows setting a fixed date and time that will be returned by
  # DateTime.now instead of the actual current time. This is useful for testing
  # purposes where consistent timestamps are required.
  module DateTimeDummy
    # The included method is a hook that gets called when this module is
    # included in another class or module.
    #
    # It sets up date time freezing functionality by extending the including
    # class/module with special date time handling methods. The method modifies
    # the including class/module's singleton class to provide dummy date time
    # capabilities.
    #
    # @param modul [Object] the class or module that includes this module
    def self.included(modul)
      class << modul
        alias really_now now

        remove_method :now rescue nil

        # Sets the dummy value for datetime handling.
        #
        # @param value [DateTime, String] the datetime value to set as dummy
        def dummy=(value)
          if value.respond_to?(:to_str)
            value = DateTime.parse(value.to_str)
          elsif value.respond_to?(:to_datetime)
            value = value.to_datetime
          end
          @dummy = value
        end

        # The dummy method provides a way to set and restore a dummy value
        # within a block.
        #
        # @param value [Object] the dummy value to set, or nil to get the
        # current dummy value
        #
        # @yield [void] yields control to the block if a value is provided
        #
        # @return [Object] the current dummy value if no value parameter is
        # provided
        # @return [Object] the result of the block if a value parameter is
        # provided
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

        # The now method returns the current time, using a dummy time if one
        # has been set. If no dummy time is set, it delegates to the actual
        # time retrieval method.
        #
        # @return [Time] the current time or a mocked time if dummy is set
        def now
          if dummy
            dummy.dup
          elsif caller.first =~ /`now`/
            really_now
          else
            really_now
          end
        end
      end
      super
    end
  end
end

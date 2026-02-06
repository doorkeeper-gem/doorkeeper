require 'tins/string_version'
require 'time'

module Tins
  # A module that provides time dummy functionality for testing and development
  # purposes.
  #
  # This module allows setting a fake current time that can be used in tests or
  # development environments where you want to control the time returned by
  # Time.now.
  module TimeDummy
    # The included method is a hook that gets called when this module is
    # included in another class or module.
    #
    # It sets up time freezing functionality by extending the including
    # class/module with special time handling methods. The method modifies the
    # including class/module's singleton class to provide dummy time
    # capabilities.
    #
    # @param modul [Object] the class or module that includes this module
    def self.included(modul)
      class << modul
        alias really_new new
        alias really_now now

        remove_method :now rescue nil
        remove_method :new rescue nil

        # Sets the dummy time value for time freezing functionality.
        #
        # This method allows setting a specific time value that will be used
        # as the frozen time when time freezing is enabled.
        #
        # @param value [Time, String] the time value to set as dummy
        def dummy=(value)
          if value.respond_to?(:to_str)
            value = Time.parse(value.to_str)
          elsif value.respond_to?(:to_time)
            value = value.to_time
          end
          @dummy = value
        end

        # The dummy method manages a dummy value for testing purposes.
        #
        # @param value [Object] the dummy value to set, or nil to get the current value
        # @return [Object] the current dummy value when value is nil
        # @yield [] executes the block with the dummy value set
        # @return [Object] the return value of the block if a block is given
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

        # The new method creates a new time instance, either by duplicating
        # the dummy time or calling the real creation method.
        #
        # @param a [ Array ] the arguments to pass to the real creation
        # method
        # @param kw [ Hash ] the keyword arguments to pass to the real
        # creation method
        #
        # @return [ Time ] the newly created time instance
        def new(*a, **kw)
          if dummy
            dummy.dup
          elsif caller.first =~ /`now`/
            really_now(**kw)
          else
            really_new(*a, **kw)
          end
        end

        # The now method returns a new instance of the current class.
        #
        # @return [Object] a new instance of the class this method is called on
        def now
          new
        end
      end
      super
    end
  end
end

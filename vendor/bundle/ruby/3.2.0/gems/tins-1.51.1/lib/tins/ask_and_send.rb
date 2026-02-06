module Tins
  # A module that provides methods to call private and protected methods on
  # objects.
  module AskAndSend
    # The ask_and_send method attempts to invoke a given method on the object
    # if that method is available.
    #
    # @param method_name [ Symbol ] the name of the method to invoke
    # @param args [ Array ] arguments to pass to the method
    # @yield [ block ] optional block to pass to the method
    # @return [ Object, nil ] the result of the method call or nil if the
    # method doesn't exist
    def ask_and_send(method_name, *args, &block)
      if respond_to?(method_name)
        __send__(method_name, *args, &block)
      end
    end

    # The ask_and_send! method attempts to invoke a private or protected method
    # on the object.
    #
    # @param method_name [ Symbol ] the name of the method to call
    # @param args [ Array ] arguments to pass to the method
    # @param block [ Proc ] optional block to pass to the method
    #
    # @return [ Object, nil ] the result of the method call or nil if the
    # method doesn't exist
    def ask_and_send!(method_name, *args, &block)
      if respond_to?(method_name, true)
        __send__(method_name, *args, &block)
      end
    end

    # The ask_and_send_or_self method attempts to invoke the specified method
    # on the object If the method exists, it calls the method with the provided
    # arguments and block If the method does not exist, it returns the object
    # itself
    #
    # @param method_name [ Symbol ] the name of the method to call
    # @param args [ Array ] the arguments to pass to the method
    # @param block [ Proc ] the block to pass to the method
    #
    # @return [ Object ] the result of the method call or self if the method
    # doesn't exist
    def ask_and_send_or_self(method_name, *args, &block)
      if respond_to?(method_name)
        __send__(method_name, *args, &block)
      else
        self
      end
    end

    # The ask_and_send_or_self! method attempts to send a message to the object
    # with the given method name and arguments. If the object responds to the
    # method, it executes the method and returns the result. If the object does
    # not respond to the method, it returns the object itself.
    #
    # @param method_name [ Symbol ] the name of the method to send
    # @param args [ Array ] the arguments to pass to the method
    # @param block [ Proc ] the block to pass to the method
    #
    # @return [ Object ] the result of the method call or the object itself if
    # the method is not found
    def ask_and_send_or_self!(method_name, *args, &block)
      if respond_to?(method_name, true)
        __send__(method_name, *args, &block)
      else
        self
      end
    end
  end
end

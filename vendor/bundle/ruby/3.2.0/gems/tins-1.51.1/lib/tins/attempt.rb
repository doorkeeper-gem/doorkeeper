module Tins
  # A module that provides functionality for attempting operations with error
  # handling and retry logic.
  module Attempt
    # Attempts code in block *attempts* times, sleeping according to *sleep*
    # between attempts and catching the exception(s) in *exception_class*.
    #
    # *sleep* is either a Proc returning a floating point number for duration
    # as seconds or a Numeric >= 0 or < 0. In the former case this is the
    # duration directly, in the latter case -*sleep* is the total number of
    # seconds that is slept before giving up, and every attempt is retried
    # after a exponentially increasing duration of seconds.
    #
    # Iff *reraise* is true the caught exception is reraised after running out
    # of attempts.
    def attempt(opts = {}, &block)
      sleep           = nil
      exception_class = StandardError
      prev_exception  = nil
      if Numeric === opts
        attempts = opts
      else
        attempts        = opts[:attempts] || 1
        attempts >= 1 or raise ArgumentError, 'at least one attempt is required'
        exception_class = opts[:exception_class] if opts.key?(:exception_class)
        sleep           = interpret_sleep(opts[:sleep], attempts)
        reraise         = opts[:reraise]
      end
      return if attempts <= 0
      count = 0
      if exception_class.nil?
        begin
          count += 1
          if block.call(count, prev_exception)
            return true
          elsif count < attempts
            sleep_duration(sleep, count)
          end
        end until count == attempts
        false
      else
        begin
          count += 1
          block.call(count, prev_exception)
          true
        rescue *exception_class
          if count < attempts
            prev_exception = $!
            sleep_duration(sleep, count)
            retry
          end
          case reraise
          when Proc
            reraise.($!)
          when Exception.class
            raise reraise, "reraised: #{$!.message}"
          when true
            raise $!, "reraised: #{$!.message}"
          else
            false
          end
        end
      end
    end

    private

    # The sleep_duration method handles sleeping for a specified duration or
    # based on a proc call.
    #
    # @param duration [ Numeric, Proc ] the duration to sleep or a proc that
    # returns the duration
    def sleep_duration(duration, count)
      case duration
      when Numeric
        sleep duration
      when Proc
        sleep duration.call(count)
      end
    end

    # Computes the base for exponential backoff that results in a specific
    # total sleep duration.
    #
    # This method solves for the base `x` in the geometric series:
    #   x^0 + x^1 + x^2 + ... + x^(attempts-1) = sleep
    #
    # The solution ensures that when using exponential delays with base `x`,
    # the total time spent across all attempts equals approximately the
    # specified sleep duration. This method of computation is used if a
    # negative number of secondes was requested in the attempt method.
    #
    # @param sleep [Numeric] The total number of seconds to distribute across
    # all attempts
    # @param attempts [Integer] The number of attempts (must be > 2)
    #
    # @return [Float] The base for exponential backoff delays
    # @raise [ArgumentError] If attempts <= 2, or if the sleep parameters are
    # invalid
    # @raise [ArgumentError] If the algorithm fails to converge after maximum
    # iterations
    def compute_duration_base(sleep, attempts)
      x1, x2  = 1, sleep
      attempts <= sleep or raise ArgumentError,
        "need less or equal number of attempts than sleep duration #{sleep}"
      x1 >= x2 and raise ArgumentError, "invalid sleep argument: #{sleep.inspect}"
      function = -> x { (0...attempts).inject { |s, i| s + x ** i } - sleep }
      f, fmid = function[x1], function[x2]
      f * fmid >= 0 and raise ArgumentError, "invalid sleep argument: #{sleep.inspect}"
      n       = 1 << 16
      epsilon = 1E-16
      root = if f < 0
               dx = x2 - x1
               x1
             else
               dx = x1 - x2
               x2
             end
      n.times do
        fmid = function[xmid = root + (dx *= 0.5)]
        fmid < 0 and root = xmid
        dx.abs < epsilon or fmid == 0 and return root
      end
      raise ArgumentError, "too many iterations (#{n})"
      result
    end

    # The interpret_sleep method determines the sleep behavior for retry attempts.
    #
    # @param sleep [Numeric, Proc, nil] the sleep duration or proc to use
    # between retries, nil if no sleep was requested
    # @param attempts [Integer] the number of retry attempts
    #
    # @return [Proc, nil] a proc that calculates the sleep duration or nil if
    # no sleep is needed
    #
    # @raise [ArgumentError] if a negative sleep value is provided with less
    # than 3 attempts
    # @raise [TypeError] if the sleep argument is not Numeric, Proc, or nil
    def interpret_sleep(sleep, attempts)
      case sleep
      when nil
      when Numeric
        if sleep < 0
          if attempts > 2
            sleep = -sleep
            duration_base = compute_duration_base sleep, attempts
            sleep = lambda { |i| duration_base ** i }
          else
            raise ArgumentError, "require > 2 attempts for negative sleep value"
          end
        end
        sleep
      when Proc
        sleep
      else
        raise TypeError, "require Proc or Numeric sleep argument"
      end
    end
  end
end

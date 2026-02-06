require 'mize/cache_methods'
require 'mize/reload'

module Mize
  module Memoize
    include CacheMethods

    # Memoize either a +method+ or a +function+. In the former case the
    # memoized results do NOT ONLY depend on the arguments, but ALSO on the
    # object the method is called on. In the latter the memoized results ONLY
    # depend on the arguments given to the function. If the +freeze+ argument
    # is true, the result is frozen if possible to make it immutable. If the
    # store_nil argument is false do not store nil results and always recompute
    # otherwise don't which is the default.
    def memoize(method: nil, function: nil, freeze: false, store_nil: true)
      Mize::MUTEX.synchronize do
        if method && function
          raise ArgumentError, 'memoize a method xor a function'
        elsif method
          wrap_method method, freeze: freeze, store_nil: store_nil
        elsif function
          wrap_method function, function: true, freeze: freeze, store_nil: store_nil
        else
          raise ArgumentError, 'missing keyword: method/function'
        end
      end
    end

    private

    class << self
      private

      def compute_result(method_id, orig_method, key, context, args, kargs, freeze)
        result = orig_method.bind(context).call(*args)
        if $DEBUG
          warn "#{context.class} cached method "\
            "#{method_id}(#{[ args, kargs ].inspect unless args.size + kargs.size == 0}) = "\
            "#{result.inspect} [#{__id__}]"
        end
        freeze and result.freeze rescue nil
        result
      end
    end

    def wrap_method(method_id, freeze: false, function: false, store_nil: true)
      verbose, $VERBOSE = $VERBOSE, nil
      if already_wrapped = Mize.wrapped[ [ self, method_id, function ] ]
        if already_wrapped == [ freeze, store_nil ]
          return method_id
        else
          raise ArgumentError,
            "encountered mismatching memoize declaration within #{self} for freeze, store_nil:"\
            " #{already_wrapped} != #{ [ freeze, store_nil ] }"
        end
      end
      include CacheMethods

      function and mc = __mize_cache__

      unless function
        prepend Mize::Reload
      end

      method_id = method_id.to_s.to_sym
      memoize_apply_visibility method_id do
        orig_method = instance_method(method_id)
        __send__(:define_method, method_id) do |*args, **kargs|
          function or mc = __mize_cache__
          key = build_key(method_id, *args, **kargs)
          if mc.exist?(key)
            mc.read(key)
          else
            result = Mize::Memoize.send(
              :compute_result, method_id, orig_method, key, self, args, kargs, freeze
            )
            if store_nil || !result.nil?
              mc.write(key, result)
            end
            result
          end
        end
      end
      Mize.wrapped[ [ self, method_id, function ] ] = [ freeze, store_nil ]
      method_id
    ensure
      $VERBOSE = verbose
    end
  end
end

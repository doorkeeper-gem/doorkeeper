module Doorkeeper
  module OAuth
    module Helpers
      module UniqueToken
        def self.generate_for(attribute, klass, options = {})
          generator_method = options.delete(:generator) || SecureRandom.method(:hex)
          token_size       = options.delete(:size)      || 32
          loop do
            token = generator_method.call(token_size)
            break token unless klass.send("find_by_#{attribute}", token)
          end
        end
      end
    end
  end
end

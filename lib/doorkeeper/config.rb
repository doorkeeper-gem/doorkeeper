module Doorkeeper
  def self.configure(&block)
    @@config = Config.new(&block)
  end

  class Config
    module ConfigOptions
      def register_config_option(name, attribute, receives_block = true)
        define_method name do |*args, &block|
          if receives_block
            self.instance_variable_set(:"@#{attribute}", block)
          else
            self.instance_variable_set(:"@#{attribute}", args[0])
          end
        end

        attr_reader attribute
        public attribute

        Doorkeeper.class_eval "
            def self.#{attribute}
              @@config.#{attribute}
            end
          "
      end

      def extended(base)
        base.send(:private, :register_method)
      end
    end

    extend ConfigOptions

    register_config_option :resource_owner_authenticator, :authenticate_resource_owner
    register_config_option :admin_authenticator, :authenticate_admin

    def initialize(&block)
      instance_eval &block
    end
  end
end


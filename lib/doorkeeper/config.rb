module Doorkeeper
  def self.configure(&block)
    @@config = Config.new(&block)
  end

  def self.validate_configuration
    raise "You have to specify doorkeeper configuration" unless class_variable_defined?(:@@config)
    unless @@config.valid?
      raise @@config.errors.values.join(',')
    end
    true
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
    include ActiveModel::Validations

    register_config_option :resource_owner_authenticator, :authenticate_resource_owner

    validates_presence_of :authenticate_resource_owner, :message => "You have to specify resource_owner_authenticator block for doorkeeper"


    def initialize(&block)
      instance_eval &block
    end
  end
end


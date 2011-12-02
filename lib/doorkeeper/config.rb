module Doorkeeper
  def self.configure(&block)
    @config = Config::Builder.new(&block).build
  end

  def self.configuration
    @config
  end

  class Config
    class Builder
      def initialize(&block)
        @config = Config.new
        instance_eval(&block)
      end

      def build
        @config
      end
    end

    module Option

      # Defines configuration options
      #
      # When you call option, it defines two methods. One method will take place
      # in the +Config+ class (getter) and the other method will take place in the
      # +Builder+ class.
      #
      # The +name+ attribute will set both getter an setter. If the +:attribute+
      # option is defined, the setter will be the specified attribute while the
      # getter will be the +name+ parameter.
      #
      # ==== Options
      #
      # * [:+attribute+] The setter that goes inside +configure+ block
      # * [+:default+] The default value in case no option was set
      #
      # ==== Examples
      #
      #    option :name
      #    option :name, :attribute => :set_name
      #    option :name, :default => "My Name"
      #
      def option(name, options = {})
        attribute = options[:attribute] || name

        Builder.instance_eval do
          define_method name do |*args, &block|
            value = block ? block : args.first
            @config.instance_variable_set(:"@#{attribute}", value)
          end
        end

        define_method attribute do |*args|
          instance_variable_get(:"@#{attribute}") || options[:default]
        end

        public attribute
      end

      def extended(base)
        base.send(:private, :option)
      end
    end

    extend Option

    option :resource_owner_authenticator, :attribute => :authenticate_resource_owner
    option :admin_authenticator,          :attribute => :authenticate_admin
    option :access_token_expires_in,      :default   => 7200

  end
end

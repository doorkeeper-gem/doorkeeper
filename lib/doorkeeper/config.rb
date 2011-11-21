module Doorkeeper
  def self.configure(&block)
    @@config = Config.new(&block)
  end

  def self.authenticate_resource_owner
    @@config.authenticate_resource_owner
  end

  def self.validate_configuration
    raise "You have to specify doorkeeper configuration" unless class_variable_defined?(:@@config)
    unless @@config.valid?
      raise @@config.errors.values.join(',')
    end
  end

  class Config
    include ActiveModel::Validations

    attr_reader :authenticate_resource_owner

    validates_presence_of :authenticate_resource_owner, :message => "You have to specify resource_owner_authenticator block"


    def initialize(&block)
      instance_eval &block
    end

    private
    attr_writer :authenticate_resource_owner
    def resource_owner_authenticator(&block)
      self.authenticate_resource_owner = block
    end
  end
end


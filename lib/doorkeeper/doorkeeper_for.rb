module Doorkeeper
  class InvalidSyntax < StandardError; end
  class DoorkeeperFor
    def initialize(options)
      options ||= {}
      raise InvalidSyntax unless options.is_a? Hash
      @filter_options = {}

      options.each do |k, v|
        self.send(k, v)
      end
    end

    # TODO: move this to Token class
    def validate_token(token)
      return false unless token
      token.accessible? and validate_token_scopes(token)
    end

    def filter_options
      @filter_options
    end

    private
    def scopes(scopes)
      @scopes = scopes
    end

    def if(if_block)
      @filter_options[:if] = if_block
    end

    def unless(unless_block)
      @filter_options[:unless] = unless_block
    end

    # TODO: move this to Token class
    def validate_token_scopes(token)
      return true if @scopes.blank?
      token.scopes.any? { |scope| @scopes.include? scope}
    end
  end

  class AllDoorkeeperFor < DoorkeeperFor
    private
    def except(actions)
      @filter_options[:except] = actions
    end
  end

  class SelectedDoorkeeperFor < DoorkeeperFor
    def initialize(*args)
      options = args.pop if args.last.is_a? Hash
      super(options)
      only(args)
    end

    private
    def only(actions)
      @filter_options[:only] = actions
    end
  end

  class DoorkeeperForBuilder
    def self.create_doorkeeper_for(*args)
      case args.first
      when :all
        AllDoorkeeperFor.new(args[1] || {})
      when Hash, nil
        raise InvalidSyntax
      else
        SelectedDoorkeeperFor.new(*args)
      end
    end
  end
end

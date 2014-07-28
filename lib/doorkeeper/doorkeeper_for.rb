module Doorkeeper
  class InvalidSyntax < StandardError
  end

  class DoorkeeperFor
    attr_reader :scopes, :name

    def initialize(options)
      options ||= {}
      fail InvalidSyntax unless options.is_a? Hash
      @filter_options = {}
      @name = ''

      options.each do |k, v|
        send("#{k}=", v)
      end
    end

    def filter_options
      @filter_options
    end

    private

    def scopes=(scopes)
      @scopes = scopes.map(&:to_s)
    end

    def if=(if_block)
      @filter_options[:if] = if_block
    end

    def unless=(unless_block)
      @filter_options[:unless] = unless_block
    end
  end

  class AllDoorkeeperFor < DoorkeeperFor
    def initialize(options)
      super

      @name = 'all'
      if @filter_options[:except].try :any?
        @name << "_except_#{@filter_options[:except].join('_')}"
      end
    end

    private

    def except=(*actions)
      @filter_options[:except] = actions
    end
  end

  class SelectedDoorkeeperFor < DoorkeeperFor
    def initialize(*args)
      options = args.extract_options!

      super(options)

      only(*args)
      @name = @filter_options[:only].join('_')
    end

    private

    def only(*actions)
      @filter_options[:only] = actions
    end
  end

  class DoorkeeperForBuilder
    def self.create_doorkeeper_for(*args)
      case args.first
      when :all
        AllDoorkeeperFor.new(args[1] || {})
      when Hash, nil
        fail InvalidSyntax
      else
        SelectedDoorkeeperFor.new(*args)
      end
    end
  end
end

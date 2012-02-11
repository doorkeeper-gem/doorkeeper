module Doorkeeper
  class InvalidSyntax < StandardError; end
  class DoorkeeperFor
    def initialize(options)
      options ||= {}
      raise InvalidSyntax unless options.is_a? Hash

      options.each do |k, v|
        self.send(k, v)
      end
    end


    def validate_token(token)
      return false unless token
      token.accessible? and validate_token_scopes(token)
    end

    def filter_options
      {}
    end

    private
    def scopes(scopes)
      @scopes = scopes
    end

    def validate_token_scopes(token)
      return true if @scopes.blank?
      token.scopes.any? { |scope| @scopes.include? scope}
    end
  end

  class AllDoorkeeperFor < DoorkeeperFor
    def filter_options
      @except ? {:except => @except} : {}
    end

    private
    def except(actions)
      @except = actions
    end
  end

  class SelectedDoorkeeperFor < DoorkeeperFor
    def initialize(*args)
      options = args.pop if args.last.is_a? Hash
      only(args)
      super(options)
    end

    def filter_options
      {:only => @only}
    end

    private
    def only(actions)
      @only = actions
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

  module Controller
    module ClassMethods
      def doorkeeper_for(*args)
        doorkeeper_for = DoorkeeperForBuilder.create_doorkeeper_for(*args)

        before_filter doorkeeper_for.filter_options do
          return if doorkeeper_for.validate_token(doorkeeper_token)
          render_options = doorkeeper_unauthorized_render_options
          if render_options.nil? || render_options.empty?
            head :unauthorized
          else
            render_options[:status] = :unauthorized
            render_options[:layout] = false if render_options[:layout].nil?
            render render_options
          end
        end
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.send(:private, :doorkeeper_token, :get_doorkeeper_token)
    end

    def doorkeeper_token
      @token ||= get_doorkeeper_token
    end

    def get_doorkeeper_token
      token = params[:access_token] || params[:bearer_token] || request.env['HTTP_AUTHORIZATION']
      if token
        token.gsub!(/Bearer /, '')
        AccessToken.find_by_token(token)
      end
    end

    def doorkeeper_unauthorized_render_options
      nil
    end
  end
end

ActionController::Base.send(:include, Doorkeeper::Controller)

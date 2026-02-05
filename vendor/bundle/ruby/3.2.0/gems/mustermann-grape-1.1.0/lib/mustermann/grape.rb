# frozen_string_literal: true

require 'mustermann'
require 'mustermann/ast/pattern'

module Mustermann
  # Grape style pattern implementation.
  #
  # @example
  #   Mustermann.new('/:foo', type: :grape) === '/bar' # => true
  #
  # @see Mustermann::Pattern
  # @see file:README.md#grape Syntax description in the README
  class Grape < AST::Pattern
    register :grape
    supported_options :params

    on(nil, '?', ')') { |c| unexpected(c) }

    on('*')  { |_c| scan(/\w+/) ? node(:named_splat, buffer.matched) : node(:splat) }
    on(':')  do |_c|
      param_name = scan(/\w+/)
      return node(:capture, param_name, constraint: "[^/\\?#\.]") { scan(/\w+/) } unless pattern

      params_opt = pattern.options[:params]
      if params_opt && params_opt[param_name] && params_opt[param_name][:type]
        param_type = params_opt[param_name][:type]
        case(param_type)
        when "Integer"
          node(:capture, param_name, constraint: /\d/) { scan(/\w+/) }
        else
          node(:capture, param_name, constraint: "[^/\\?#\.]") { scan(/\w+/) }
        end
      else
        node(:capture, param_name, constraint: "[^/\\?#\.]") { scan(/\w+/) }
      end
    end
    on('\\') { |_c| node(:char, expect(/./)) }
    on('(')  { |_c| node(:optional, node(:group) { read unless scan(')') }) }
    on('|')  { |_c| node(:or) }

    on '{' do |_char|
      type = scan('+') ? :named_splat : :capture
      name = expect(/[\w\.]+/)
      type = :splat if (type == :named_splat) && (name == 'splat')
      expect('}')
      node(type, name)
    end

    suffix '?' do |_char, element|
      node(:optional, element)
    end
  end
end

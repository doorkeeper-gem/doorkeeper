# frozen_string_literal: true

require "dry/types/coercions/params"

module Dry
  module Types
    options = {namespace: "params"}

    {
      "nil" => :to_nil,
      "date" => :to_date,
      "date_time" => :to_date_time,
      "time" => :to_time,
      "true" => :to_true,
      "false" => :to_false,
      "integer" => :to_int,
      "float" => :to_float,
      "decimal" => :to_decimal,
      "array" => :to_ary,
      "hash" => :to_hash,
      "symbol" => :to_symbol
    }.each do |name, method|
      register("params.#{name}") do
        self["nominal.#{name}"].with(**options).constructor(Coercions::Params.method(method))
      end
    end

    register("params.bool") do
      self["params.true"] | self["params.false"]
    end

    register("params.string", self["string"].with(**options))

    COERCIBLE.each_key do |name|
      register("optional.params.#{name}", self["params.nil"] | self["params.#{name}"])
    end
  end
end

module Appraisal
  # Contains methods for various operations
  module Utils
    def self.support_parallel_installation?
      Gem::Version.create(Bundler::VERSION) >= Gem::Version.create('1.4.0.pre.1')
    end

    def self.format_string(object, enclosing_object = false)
      case object
      when Hash
        items = object.map do |key, value|
          format_hash_value(key, value)
        end

        if enclosing_object
          "{ #{items.join(', ')} }"
        else
          items.join(', ')
        end
      else
        object.inspect
      end
    end

    def self.format_hash_value(key, value)
      key = format_string(key, true)
      value = format_string(value, true)

      if key.start_with?(":")
        "#{key.sub(/^:/, "")}: #{value}"
      else
        "#{key} => #{value}"
      end
    end

    def self.format_arguments(arguments)
      unless arguments.empty?
        arguments.map { |object| format_string(object, false) }.join(', ')
      end
    end

    def self.join_parts(parts)
      parts.reject(&:nil?).reject(&:empty?).join("\n\n").strip
    end

    def self.prefix_path(path)
      if path !~ /^(?:\/|\S:)/ && path !~ /^\S+:\/\// && path !~ /^\S+@\S+:/
        cleaned_path = path.gsub(/(^|\/)\.(?:\/|$)/, "\\1")
        File.join("..", cleaned_path)
      else
        path
      end
    end

    def self.bundler_version
      Gem::Specification.
        detect { |spec| spec.name == "bundler" }.
        version.
        to_s
    end
  end
end

module Tins
  # A module for adding annotations to classes and methods
  #
  # This module provides functionality to add metadata annotations to classes and
  # methods, allowing for enhanced documentation and introspection capabilities
  module Annotate
    # The annotate method sets up annotation functionality for a given name
    # by defining methods to set and retrieve annotations on class methods
    #
    # @param name [ Symbol ] the name of the annotation to define
    def annotate(name)
      singleton_class.class_eval do
        define_method(name) do |annotation = :annotated|
          instance_variable_set "@__annotation_#{name}__", annotation
        end

        define_method("#{name}_of") do |method_name|
          __send__("#{name}_annotations")[method_name]
        end

        define_method("#{name}_annotations") do
          if instance_variable_defined?("@__annotation_#{name}_annotations__")
            instance_variable_get "@__annotation_#{name}_annotations__"
          else
            instance_variable_set "@__annotation_#{name}_annotations__", {}
          end
        end

        old_method_added = instance_method(:method_added)
        define_method(:method_added) do |method_name|
          old_method_added.bind(self).call method_name
          if annotation = instance_variable_get("@__annotation_#{name}__")
            __send__("#{name}_annotations")[method_name] = annotation
          end
          instance_variable_set "@__annotation_#{name}__", nil
        end
      end

      define_method("#{name}_annotations") do
        self.class.__send__("#{name}_annotations")
      end

      define_method("#{name}_of") do |method_name|
        self.class.__send__("#{name}_of", method_name)
      end
    end
  end
end

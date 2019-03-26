# frozen_string_literal: true

module Doorkeeper
  module Generators
    class ViewsGenerator < ::Rails::Generators::Base
      source_root File.expand_path("../../../app/views", __dir__)

      desc "Copies default Doorkeeper views and layouts to your application."

      def manifest
        directory "doorkeeper", "app/views/doorkeeper"
        directory "layouts/doorkeeper", "app/views/layouts/doorkeeper"
      end
    end
  end
end

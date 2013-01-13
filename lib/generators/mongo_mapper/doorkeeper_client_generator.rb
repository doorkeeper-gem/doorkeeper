module MongoMapper
  module Generators
    class DoorkeeperClientGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path('../templates', __FILE__)

      def generate_model
        invoke "mongo_mapper:model", [name] unless model_exists?
      end

      def inject_doorkeeper_content
        content =
<<-CONTENT
  # Setup doorkeeper client extension
  plugin DoorkeeperClient

  key :name,         String
  key :uid,          String
  key :secret,       String
  key :redirect_uri, String

  attr_accessible :name, :redirect_uri
CONTENT

        inject_into_file model_path, content, :after => "include MongoMapper::Document\n" if model_exists?
      end

      def generate_indexes
        template "indexes.rb", "db/indexes.rb"
      end

    private

      def model_exists?
        File.exists?(File.join(destination_root, model_path))
      end

      def model_path
        @model_path ||= File.join("app", "models", "#{file_path}.rb")
      end
    end
  end
end

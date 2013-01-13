module Mongoid
  module Generators
    class DoorkeeperClientGenerator < ::Rails::Generators::NamedBase
      def generate_model
        invoke "mongoid:model", [name] unless model_exists?
      end

      def inject_doorkeeper_content
        content =
<<-CONTENT
  # Setup doorkeeper client extension
  doorkeeper_client!

  field :name, :type => String
  field :uid, :type => String
  field :secret, :type => String
  field :redirect_uri, :type => String

  attr_accessible :name, :redirect_uri

  index({ uid: 1 }, { unique: true })
CONTENT

        inject_into_file model_path, content, :after => "include Mongoid::Document\n" if model_exists?
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

module Doorkeeper
  module Couchbase
    class ViewsGenerator < ::Rails::Generators::Base
      desc "Ensures the design documents for map reduce in couchbase exist"

      def install
        ::Couchbase::Model::Configuration.design_documents_paths = [File.expand_path(File.join(File.expand_path("../", __FILE__), '../../../doorkeeper/models/couchbase'))]
        ::Doorkeeper::AccessToken.ensure_design_document!
        ::Doorkeeper::Application.ensure_design_document!
      end
    end
  end
end

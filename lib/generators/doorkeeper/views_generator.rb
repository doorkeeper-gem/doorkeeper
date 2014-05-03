module Doorkeeper
  module Generators
    class ViewsGenerator < ::Rails::Generators::Base
      source_root File.expand_path('../../../../app/views/doorkeeper', __FILE__)

      desc 'Copies default Doorkeeper views to your application.'

      def manifest
        directory 'applications', 'app/views/doorkeeper/applications'
        directory 'authorizations', 'app/views/doorkeeper/authorizations'
        directory 'authorized_applications', 'app/views/doorkeeper/authorized_applications'
      end
    end
  end
end

module Doorkeeper
  module Generators
    class ViewsGenerator < ::Rails::Generators::Base
      source_root File.expand_path('../../../../app', __FILE__)

      desc "Copies default Doorkeeper views and asset to your application."

      def manifest
        %w(new error).each do |filename|
          copy_file "views/doorkeeper/authorizations/#{filename}.html.erb",
                    "app/views/doorkeeper/authorizations/#{filename}.html.erb"
        end
        copy_file 'assets/stylesheets/doorkeeper/application.css', 'app/assets/stylesheets/doorkeeper/application.css'
      end
    end
  end
end

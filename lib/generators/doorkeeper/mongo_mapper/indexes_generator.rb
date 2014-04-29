module Doorkeeper
  module MongoMapper
    class IndexesGenerator < ::Rails::Generators::Base
      source_root File.expand_path('../../templates', __FILE__)
      desc 'Creates an indexes file for use with MongoMapper\'s rake db:index'

      def install
        template 'indexes.rb' 'db/indexes.rb'
      end
    end
  end
end

class Doorkeeper::InstallGenerator < ::Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('templates', __dir__)
  desc 'Installs Doorkeeper.'

  def install
    template 'initializer.rb', 'config/initializers/doorkeeper.rb'
    copy_file File.expand_path('../../../config/locales/en.yml', __dir__), 'config/locales/doorkeeper.en.yml'
    route 'use_doorkeeper'
    readme 'README'
  end
end

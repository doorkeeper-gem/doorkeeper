class Doorkeeper::InstallGenerator < ::Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Installs Doorkeeper.'

  def install
    template 'initializer.rb', 'config/initializers/doorkeeper.rb'
    install_locales
    route 'use_doorkeeper'
    readme 'README'
  end

  private

  def install_locales
    Dir.glob(File.expand_path('../../../../config/locales/*.yml', __FILE__)) do |file|
      locale = File.basename(file, ".yml")
      copy_file file, "config/locales/doorkeeper.#{locale}.yml"
    end
  end
end

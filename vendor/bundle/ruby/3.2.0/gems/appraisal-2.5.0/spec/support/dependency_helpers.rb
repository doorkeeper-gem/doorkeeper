module DependencyHelpers
  def build_gem(gem_name, version = '1.0.0')
    ENV['GEM_HOME'] = TMP_GEM_ROOT

    unless File.exist? "tmp/gems/gems/#{gem_name}-#{version}"
      FileUtils.mkdir_p "tmp/gems/#{gem_name}/lib"

      FileUtils.cd "tmp/gems/#{gem_name}" do
        gemspec = "#{gem_name}.gemspec"
        lib_file = "lib/#{gem_name}.rb"

        File.open gemspec, 'w' do |file|
          file.puts <<-gemspec
            Gem::Specification.new do |s|
              s.name    = #{gem_name.inspect}
              s.version = #{version.inspect}
              s.authors = 'Mr. Smith'
              s.summary = 'summary'
              s.files   = #{lib_file.inspect}
            end
          gemspec
        end

        File.open lib_file, 'w' do |file|
          file.puts "$#{gem_name}_version = '#{version}'"
        end

        `gem build #{gemspec} 2>&1`
        `gem install -lN #{gem_name}-#{version}.gem -v #{version} 2>&1`
      end
    end
  end

  def build_gems(gems)
    gems.each { |gem| build_gem(gem) }
  end

  def build_git_gem(gem_name, version = '1.0.0')
    build_gem gem_name, version

    Dir.chdir "tmp/gems/#{gem_name}" do
      `git init .`
      `git config user.email "appraisal@thoughtbot.com"`
      `git config user.name "Appraisal"`
      `git add .`
      `git commit -a -m "initial commit"`
    end

    # Cleanup Bundler cache path manually for now
    git_cache_path = File.join(ENV["GEM_HOME"], "cache", "bundler", "git")

    Dir[File.join(git_cache_path, "#{gem_name}-*")].each do |path|
      FileUtils.rm_r(path)
    end
  end

  def build_git_gems(gems)
    gems.each { |gem| build_git_gem(gem) }
  end
end

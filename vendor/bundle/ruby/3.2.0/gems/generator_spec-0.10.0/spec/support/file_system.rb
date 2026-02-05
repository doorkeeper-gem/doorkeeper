module Helpers
  module FileSystem
    def write_file(file_name, contents)
      write_directory(TMP_ROOT)
      ::File.open(file_name.to_s, 'w') {|f| f.write(contents) }
    end
    
    def write_directory(name)
      FileUtils.mkdir_p(name)
    end

    def delete_directory(name)
      FileUtils.rm_rf(name)
    end
  end
end

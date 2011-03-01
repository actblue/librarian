require 'librarian/support/abstract_method'

module Librarian
  module Source
    # Requires that the including source class have methods:
    #   #path
    #   #root_module
    module Local

      include Support::AbstractMethod

      abstract_method :path

      def install!(dependency)
        cache_path = dependency_cache_path(dependency)
        install_path = dependency_install_path(dependency)
        if install_path.exist?
          debug { "Deleting #{relative_path_to(install_path)}" }
          install_path.rmtree
        end
        debug { "Copying #{relative_path_to(cache_path)} to #{relative_path_to(install_path)}" }
        FileUtils.cp_r(cache_path, install_path)
      end

      def manifest_search_paths(dependency)
        paths = [path, path.join(dependency.name)]
        paths.select{|s| s.exist?}
      end

      def manifest?(dependency)
        manifest_search_paths(dependency).any?{|s| dependency.manifest?(s)}
      end

      def dependency_cache_path(dependency)
        manifest_search_paths(dependency).select{|s| dependency.manifest?(s)}.first
      end

      def dependency_install_path(dependency)
        root_module.install_path.join(dependency.name)
      end

    private

      def relative_path_to(path)
        root_module.project_relative_path_to(path)
      end

      def debug
        root_module.ui.debug "[Librarian] #{yield}"
      end

    end
  end
end
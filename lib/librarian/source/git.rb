require 'fileutils'
require 'pathname'
require 'digest'

require 'librarian/source/git/repository'
require 'librarian/source/local'

module Librarian
  module Source
    class Git

      include Local

      class << self

        LOCK_NAME = 'GIT'

        def lock_name
          LOCK_NAME
        end

        def from_lock_options(environment, options)
          new(environment, options[:remote], options.reject{|k, v| k == :remote})
        end

        def from_spec_args(environment, uri, options)
          recognized_options = [:ref, :path]
          unrecognized_options = options.keys - recognized_options
          unrecognized_options.empty? or raise Error, "unrecognized options: #{unrecognized_options.join(", ")}"

          new(environment, uri, options)
        end

      end

      DEFAULTS = {
        :ref => 'master'
      }

      attr_accessor :environment
      private :environment=

      attr_accessor :uri, :ref, :sha, :path
      private :uri=, :ref=, :sha=, :path=

      def initialize(environment, uri, options)
        self.environment = environment
        self.uri = uri
        self.ref = options[:ref] || DEFAULTS[:ref]
        self.sha = options[:sha]
        self.path = options[:path]

        @repository = nil
        @repository_cache_path = nil
      end

      def to_s
        path ? "#{uri}##{ref}(#{path})" : "#{uri}##{ref}"
      end

      def ==(other)
        other &&
        self.class  == other.class  &&
        self.uri    == other.uri    &&
        self.ref    == other.ref    &&
        self.path   == other.path   &&
        (self.sha.nil? || other.sha.nil? || self.sha == other.sha)
      end

      def to_spec_args
        options = {}
        options.merge!(:ref => ref) if ref != DEFAULTS[:ref]
        options.merge!(:path => path) if path
        [uri, options]
      end

      def to_lock_options
        options = {:remote => uri, :ref => ref, :sha => sha}
        options.merge!(:path => path) if path
        options
      end

      def pinned?
        !!sha
      end

      def unpin!
        @sha = nil
      end

      def cache!(names)
        unless repository.git?
          repository.path.rmtree if repository.path.exist?
          repository.path.mkpath
          repository.clone!(uri)
        end
        repository.reset_hard!
        unless repository.checked_out?(sha)
          remote = repository.default_remote
          repository.fetch!(remote)
          repository.fetch!(remote, :tags => true)

          self.sha = repository.hash_from(remote, ref) unless sha
          repository.checkout!(sha) unless repository.checked_out?(sha)

          raise Error, "failed to checkout #{sha}" unless repository.checked_out?(sha)
        end
      end

      def repository_cache_path
        @repository_cache_path ||= begin
          dir = path ? "#{uri}/#{path}" : uri
          dir = Digest::MD5.hexdigest(dir)
          environment.cache_path.join("source/git/#{dir}")
        end
      end

      def repository
        @repository ||= begin
          Repository.new(environment, repository_cache_path)
        end
      end

      def filesystem_path
        @filesystem_path ||= path ? repository.path.join(path) : repository.path
      end

    end
  end
end

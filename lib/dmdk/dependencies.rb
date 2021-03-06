# frozen_string_literal: true

require 'net/http'
require 'mkmf'

# Make the MakeMakefile logger write file output to null.
module MakeMakefile::Logging
  @logfile = File::NULL
  @quiet = true
end

module DMDK
  module Dependencies
    class DocuModelVersions
      VersionNotDetected = Class.new(StandardError)

      def ruby_version
        read_documodel_file('.ruby-version').strip || raise(VersionNotDetected, "Failed to determine DocuModel's Ruby version")
      end

      def bundler_version
        read_documodel_file('Gemfile.lock')[/BUNDLED WITH\n +(\d+.\d+.\d+)/, 1] || raise(VersionNotDetected, "Failed to determine DocuModel's Bundler version")
      end

      private

      def read_documodel_file(filename)
        return local_documodel_path(filename).read if local_documodel_path(filename).exist?

        read_remote_file(filename)
      end

      def local_documodel_path(filename)
        Pathname.new(__dir__).join("../../documodel/#{filename}").expand_path
      end

      def read_remote_file(filename)
        uri = URI("https://gitlab.com/gitlab-org/gitlab/raw/master/#{filename}")
        Net::HTTP.get(uri)
      rescue SocketError
        abort 'Internet connection is required to set up DMDK, please ensure you have an internet connection'
      end
    end

    class Checker
      EXPECTED_GO_VERSION = '1.14'
      EXPECTED_YARN_VERSION = '1.12'
      EXPECTED_NODEJS_VERSION = '12.10'
      EXPECTED_POSTGRESQL_VERSION = '9.6.x'

      attr_reader :error_messages

      def initialize
        @error_messages = []
      end

      def check_all
        check_ruby_version
        check_bundler_version
        check_go_version
        check_nodejs_version
        check_yarn_version
        check_postgresql_version

        check_graphicsmagick_installed
        check_exiftool_installed
        check_minio_installed
        check_runit_installed
      end

      def check_binary(binary)
        find_executable(binary).tap do |result|
          @error_messages << "#{binary} does not exist. You may need to check your PATH or install a missing package." unless result
        end
      end

      def check_ruby_version
        return unless check_binary('ruby')

        actual = Gem::Version.new(RUBY_VERSION)
        expected = Gem::Version.new(DocuModelVersions.new.ruby_version)

        @error_messages << require_minimum_version('Ruby', actual, expected) if actual < expected
      end

      def check_bundler_version
        return if bundler_version_ok? || alt_bundler_version_ok?

        @error_messages << <<~BUNDLER_VERSION_NOT_MET
          Please install Bundler version #{expected_bundler_version}.
          gem install bundler -v '= #{expected_bundler_version}'
        BUNDLER_VERSION_NOT_MET
      end

      def bundler_version_ok?
        cmd = Shellout.new("bundle _#{expected_bundler_version}_ --version >/dev/null 2>&1")
        cmd.try_run
        cmd.success?
      end

      def alt_bundler_version_ok?
        # On some systems, most notably Gentoo, Ruby Gems get patched to use a
        # custom wrapper. Because of this, we cannot use the `bundle
        # _$VERSION_` syntax and need to fall back to using `bundle --version`
        # on a best effort basis.
        actual = Shellout.new('bundle --version').try_run
        actual = actual[/Bundler version (\d+\.\d+.\d+)/, 1]

        Gem::Version.new(actual) == Gem::Version.new(expected_bundler_version)
      end

      def check_go_version
        return unless check_binary('go')

        current_version = `go version`[/go((\d+.\d+)(.\d+)?)/, 1]

        actual = Gem::Version.new(current_version)
        expected = Gem::Version.new(EXPECTED_GO_VERSION)
        @error_messages << require_minimum_version('Go', actual, expected) if actual < expected

      rescue Errno::ENOENT
        @error_messages << missing_dependency('Go', minimum_version: EXPECTED_GO_VERSION)
      end

      def check_nodejs_version
        return unless check_binary('node')

        current_version = `node --version`[/v(\d+\.\d+\.\d+)/, 1]

        actual = Gem::Version.new(current_version)
        expected = Gem::Version.new(EXPECTED_NODEJS_VERSION)

        @error_messages << require_minimum_version('Node.js', actual, expected) if actual < expected

      rescue Errno::ENOENT
        @error_messages << missing_dependency('Node.js', minimum_version: EXPECTED_NODEJS_VERSION)
      end

      def check_yarn_version
        return unless check_binary('yarn')

        current_version = `yarn --version`

        actual = Gem::Version.new(current_version)
        expected = Gem::Version.new(EXPECTED_YARN_VERSION)

        @error_messages << require_minimum_version('Yarn', actual, expected) if actual < expected

      rescue Errno::ENOENT
        @error_messages << missing_dependency('Yarn', minimum_version: expected)
      end

      def check_postgresql_version
        return unless check_binary('psql')

        current_postgresql_version = `psql --version`[/psql \(PostgreSQL\) (\d+\.\d+)/, 1]

        actual = Gem::Version.new(current_postgresql_version)
        expected = Gem::Version.new(EXPECTED_POSTGRESQL_VERSION)

        @error_messages << require_minimum_version('PostgreSQL', actual, expected) if actual.segments[0] < expected.segments[0]
      end

      def check_graphicsmagick_installed
        @error_messages << missing_dependency('GraphicsMagick') unless system("gm version >/dev/null 2>&1")
      end

      def check_exiftool_installed
        @error_messages << missing_dependency('Exiftool') unless system("exiftool -ver >/dev/null 2>&1")
      end

      def check_minio_installed
        @error_messages << missing_dependency('MinIO') unless system("minio --help >/dev/null 2>&1")
      end

      def check_runit_installed
        @error_messages << missing_dependency('Runit') unless system("which runsvdir >/dev/null 2>&1")
      end

      def require_minimum_version(dependency, actual, expected)
        "#{dependency} version #{actual} detected, please install #{dependency} version #{expected} or higher."
      end

      def missing_dependency(dependency, minimum_version: nil)
        message = "#{dependency} is not installed, please install #{dependency}"
        message += "#{minimum_version} or higher" unless minimum_version.nil?
        message + "."
      end

      private

      def expected_bundler_version
        @expected_bundler_version ||= DocuModelVersions.new.bundler_version.freeze
      end
    end
  end
end

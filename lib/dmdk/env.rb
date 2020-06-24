# frozen_string_literal: true

require 'pathname'
require 'shellwords'

require_relative 'config'

module DMDK
  module Env
    class << self
      def exec(argv)
        if argv.empty?
          print_env
          exit
        else
          exec_env(argv)
        end
      end

      private

      def print_env
        env.each do |k, v|
          puts "export #{Shellwords.shellescape(k)}=#{Shellwords.shellescape(v)}"
        end
      end

      def exec_env(argv)
        # Use Kernel:: namespace to avoid recursive method call
        Kernel.exec(env, *argv)
      end

      def env
        case get_project
        # leave this gitaly reference in for now
        when 'gitaly'
          {
            'PGHOST' => config.postgresql.dir.to_s,
            'PGPORT' => config.postgresql.port.to_s
          }
        else
          {}
        end
      end

      def get_project
        relative_path = Pathname.new(Dir.pwd).relative_path_from(DMDK.root).to_s
        relative_path.split('/').first
      end

      def config
        @config ||= DMDK::Config.new
      end
    end
  end
end

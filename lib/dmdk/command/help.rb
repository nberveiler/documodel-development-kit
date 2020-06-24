# frozen_string_literal: true

require 'fileutils'

module DMDK
  module Command
    class Help
      def run(stdout: $stdout, stderr: $stderr)
        DMDK::Logo.print
        stdout.puts File.read(DMDK.root.join('HELP'))
      end
    end
  end
end

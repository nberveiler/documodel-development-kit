# frozen_string_literal: true

module DMDK
  module Diagnostic
    class Dependencies < Base
      TITLE = 'DMDK Dependencies'

      def diagnose
        @checker = DMDK::Dependencies::Checker.new
        @checker.check_all
      end

      def success?
        @checker.error_messages.empty?
      end

      def detail
        messages = @checker.error_messages.join("\n").chomp
        return if messages.empty?

        <<~MESSAGE
          #{messages}

          For details on how to install, please visit:

          https://gitlab.com/gitlab-org/gitlab-development-kit/blob/master/doc/prepare.md#platform-specific-setup
        MESSAGE
      end
    end
  end
end

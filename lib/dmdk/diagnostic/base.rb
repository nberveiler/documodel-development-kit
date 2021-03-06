# frozen_string_literal: true

require 'stringio'

module DMDK
  module Diagnostic
    class Base
      def diagnose
        raise NotImplementedError
      end

      def success?
        raise NotImplementedError
      end

      def message
        raise NotImplementedError unless self.class::TITLE

        <<~MESSAGE

          #{self.class::TITLE}
          #{'-' * 80}
          #{detail}
        MESSAGE
      end

      def detail
        ''
      end

      private

      def config
        @config ||= DMDK::Config.new
      end
    end
  end
end

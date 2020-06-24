# frozen_string_literal: true

require 'spec_helper'

describe DMDK::Diagnostic do
  describe '.all' do
    it 'creates instances of all DMDK::Diagnostic classes' do
      expect { described_class.all }.not_to raise_error
    end

    it 'contains only diagnostic classes' do
      diagnostic_classes = [
        DMDK::Diagnostic::RubyGems,
        DMDK::Diagnostic::Version,
        DMDK::Diagnostic::Configuration,
        DMDK::Diagnostic::Git,
        DMDK::Diagnostic::Dependencies,
        DMDK::Diagnostic::PendingMigrations,
        DMDK::Diagnostic::Geo,
        DMDK::Diagnostic::Status,
        DMDK::Diagnostic::Re2,
        DMDK::Diagnostic::Golang,
        DMDK::Diagnostic::StaleServices
      ]

      expect(described_class.all.map(&:class)).to eq(diagnostic_classes)
    end
  end
end

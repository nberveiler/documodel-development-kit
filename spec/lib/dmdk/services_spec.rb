# frozen_string_literal: true

require 'spec_helper'

describe DMDK::Services do
  describe '.all' do
    it 'contains Service classes' do
      service_classes = []

      expect(described_class.all.map(&:class)).to eq(service_classes)
    end
  end
end

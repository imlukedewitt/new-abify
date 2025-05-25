# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/services/liquid/filters/workflow_filters'

class TestClass
  include WorkflowFilters
end

RSpec.describe WorkflowFilters do
  let(:test_instance) { TestClass.new }

  describe '#present?' do
    it 'returns false for nil and empty values' do
      expect(test_instance.present?(nil)).to be false
      expect(test_instance.present?("")).to be false
      expect(test_instance.present?("   ")).to be false
      expect(test_instance.present?([])).to be false
      expect(test_instance.present?({})).to be false
    end

    it 'returns true for non-empty strings' do
      expect(test_instance.present?("hello")).to be true
      expect(test_instance.present?("  hello  ")).to be true
    end

    it 'returns true for numbers and booleans' do
      expect(test_instance.present?(42)).to be true
      expect(test_instance.present?(0)).to be true
      expect(test_instance.present?(true)).to be true
      expect(test_instance.present?(false)).to be true
    end

    it 'returns true for non-empty collections' do
      expect(test_instance.present?([1, 2, 3])).to be true
      expect(test_instance.present?({ a: 1 })).to be true
    end

    it 'returns true for other object types' do
      expect(test_instance.present?(:symbol)).to be true
      expect(test_instance.present?(Date.today)).to be true
    end
  end

  describe '#blank?' do
    it 'returns the opposite of present?' do
      # Test a few key cases to verify it inverts present?
      expect(test_instance.blank?("hello")).to be false
      expect(test_instance.blank?(nil)).to be true
      expect(test_instance.blank?("")).to be true
      expect(test_instance.blank?([1, 2])).to be false
      expect(test_instance.blank?([])).to be true
    end
  end
end

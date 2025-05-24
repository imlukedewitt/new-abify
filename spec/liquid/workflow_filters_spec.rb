require 'rails_helper'
require_relative '../../app/liquid/filters/workflow_filters'

class TestClass
  include WorkflowFilters
end

RSpec.describe WorkflowFilters do
  let(:test_instance) { TestClass.new }

  describe '#present?' do
    context 'with nil values' do
      it 'returns false for nil' do
        expect(test_instance.present?(nil)).to be false
      end
    end

    context 'with string values' do
      it 'returns true for non-empty string' do
        expect(test_instance.present?("hello")).to be true
      end

      it 'returns false for empty string' do
        expect(test_instance.present?("")).to be false
      end

      it 'returns false for whitespace-only string' do
        expect(test_instance.present?("   ")).to be false
      end

      it 'returns false for string with tabs and newlines' do
        expect(test_instance.present?("\t\n  \r")).to be false
      end

      it 'returns true for string with content and whitespace' do
        expect(test_instance.present?("  hello  ")).to be true
      end
    end

    context 'with numeric values' do
      it 'returns true for positive integer' do
        expect(test_instance.present?(42)).to be true
      end

      it 'returns true for negative integer' do
        expect(test_instance.present?(-5)).to be true
      end

      it 'returns true for zero' do
        expect(test_instance.present?(0)).to be true
      end

      it 'returns true for positive float' do
        expect(test_instance.present?(3.14)).to be true
      end

      it 'returns true for negative float' do
        expect(test_instance.present?(-2.5)).to be true
      end

      it 'returns true for zero float' do
        expect(test_instance.present?(0.0)).to be true
      end
    end

    context 'with boolean values' do
      it 'returns true for true' do
        expect(test_instance.present?(true)).to be true
      end

      it 'returns true for false' do
        expect(test_instance.present?(false)).to be true
      end
    end

    context 'with array values' do
      it 'returns true for non-empty array' do
        expect(test_instance.present?([1, 2, 3])).to be true
      end

      it 'returns false for empty array' do
        expect(test_instance.present?([])).to be false
      end

      it 'returns true for array with nil elements' do
        expect(test_instance.present?([nil, nil])).to be true
      end
    end

    context 'with hash values' do
      it 'returns true for non-empty hash' do
        expect(test_instance.present?({ a: 1, b: 2 })).to be true
      end

      it 'returns false for empty hash' do
        expect(test_instance.present?({})).to be false
      end

      it 'returns true for hash with nil values' do
        expect(test_instance.present?({ a: nil, b: nil })).to be true
      end
    end

    context 'with other/undefined types' do
      it 'returns true for symbols' do
        expect(test_instance.present?(:symbol)).to be true
      end

      it 'returns true for regex' do
        expect(test_instance.present?(/pattern/)).to be true
      end

      it 'returns true for date objects' do
        expect(test_instance.present?(Date.today)).to be true
      end
    end
  end
end

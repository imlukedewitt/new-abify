# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Liquid::Processor do
  describe '#render' do
    it 'processes a simple liquid template' do
      template = "Hello {{name}}!"
      context_data = { name: "World" }

      processor = described_class.new(template, context_data)
      result = processor.render

      expect(result).to eq("Hello World!")
    end

    it 'processes templates with nested data access' do
      template = "Customer ID: {{row.customer_id}}"
      context_data = {
        row: {
          customer_id: "12345",
          customer_reference: "CUST-001"
        }
      }

      processor = described_class.new(template, context_data)
      result = processor.render

      expect(result).to eq("Customer ID: 12345")
    end

    it 'processes templates with array access' do
      template = "First payment profile ID: {{response[0].id}}"
      context_data = {
        response: [
          { id: "pp_123", created_at: "2023-01-01" },
          { id: "pp_456", created_at: "2023-01-02" }
        ]
      }

      processor = described_class.new(template, context_data)
      result = processor.render

      expect(result).to eq("First payment profile ID: pp_123")
    end

    describe 'with custom filters' do
      it 'processes present? filter for non-empty string' do
        template = "{{ value | present? }}"
        context_data = { value: "hello" }

        processor = described_class.new(template, context_data)
        result = processor.render

        expect(result).to eq("true")
      end

      it 'processes blank? filter for empty string' do
        template = "{{ value | blank? }}"
        context_data = { value: "" }

        processor = described_class.new(template, context_data)
        result = processor.render

        expect(result).to eq("true")
      end
    end
  end

  describe '#render_as_boolean' do
    it 'returns true when liquid processes to "true"' do
      template = "{{ value | present? }}"
      context_data = { value: "hello" }

      processor = described_class.new(template, context_data)
      result = processor.render_as_boolean

      expect(result).to be true
    end

    it 'returns false when liquid processes to "false"' do
      template = "{{ value | present? }}"
      context_data = { value: nil }

      processor = described_class.new(template, context_data)
      result = processor.render_as_boolean

      expect(result).to be false
    end

    it 'delegates boolean conversion to DataUtils' do
      template = "some_value"
      processor = described_class.new(template)

      expect(DataUtils).to receive(:to_boolean).with("some_value").and_return(true)
      expect(processor.render_as_boolean).to be true
    end
  end

  describe '#valid?' do
    it 'returns true for valid liquid template' do
      template = "Hello {{name}}!"
      processor = described_class.new(template)

      expect(processor.valid?).to be true
    end

    it 'returns false for invalid liquid template' do
      template = "Hello {{name"
      processor = described_class.new(template)

      expect(processor.valid?).to be false
    end

    it 'returns true for template with conditionals' do
      template = "{% if user %}Hello {{user.name}}{% endif %}"
      processor = described_class.new(template)

      expect(processor.valid?).to be true
    end
  end

  describe '#validation_errors' do
    it 'returns nil for valid template' do
      template = "Hello {{name}}!"
      processor = described_class.new(template)

      expect(processor.validation_errors).to be_nil
    end

    it 'returns error message for invalid template' do
      template = "Hello {{name"
      processor = described_class.new(template)

      expect(processor.validation_errors).to include("Variable '{{' was not properly terminated")
    end
  end
end

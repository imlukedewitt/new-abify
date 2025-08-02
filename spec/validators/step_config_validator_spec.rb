# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepConfigValidator do
  describe '#valid?' do
    context 'when config is not a hash' do
      it 'is invalid' do
        validator = described_class.new('not a hash')
        expect(validator.valid?).to be false
        expect(validator.errors).to include('step config must be a hash')
      end
    end

    context 'when config lacks liquid_templates' do
      it 'is invalid' do
        validator = described_class.new({ 'other' => 'stuff' })
        expect(validator.valid?).to be false
        expect(validator.errors).to include('step config must include liquid_templates hash')
      end
    end

    context 'when config has valid structure' do
      let(:valid_config) do
        {
          'liquid_templates' => {
            'name' => 'Test Step',
            'url' => '{{base_url}}/api/test',
            'method' => 'post',
            'body' => '{"data": "{{row.value}}"}',
            'success_data' => {
              'result' => '{{response.result}}'
            }
          }
        }
      end

      it 'is valid' do
        validator = described_class.new(valid_config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when required keys are missing' do
      let(:config_missing_required) do
        {
          'liquid_templates' => {
            'method' => 'get'
            # Missing 'name' and 'url'
          }
        }
      end

      it 'is invalid' do
        validator = described_class.new(config_missing_required)
        expect(validator.valid?).to be false
        expect(validator.errors).to include('step config must include name in liquid_templates')
        expect(validator.errors).to include('step config must include url in liquid_templates')
      end
    end

    context 'when config has invalid Liquid syntax' do
      let(:config_with_bad_syntax) do
        {
          'liquid_templates' => {
            'name' => 'Test',
            'url' => '{{base_url}/incomplete' # Missing closing braces
          }
        }
      end

      it 'is invalid' do
        validator = described_class.new(config_with_bad_syntax)
        expect(validator.valid?).to be false
        expect(validator.errors.first).to include('invalid Liquid syntax in liquid_templates.url')
      end
    end
  end
end

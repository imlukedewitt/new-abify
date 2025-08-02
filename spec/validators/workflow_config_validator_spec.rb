# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowConfigValidator do
  describe '#valid?' do
    context 'when config is nil' do
      it 'is valid' do
        validator = described_class.new(nil)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when config is not a hash' do
      it 'is invalid' do
        validator = described_class.new('not a hash')
        expect(validator.valid?).to be false
        expect(validator.errors).to include('workflow config must be a hash')
      end
    end

    context 'when config has valid structure' do
      let(:valid_config) do
        {
          'liquid_templates' => {
            'group_by' => '{{row.category}}',
            'sort_by' => '{{row.priority}}'
          },
          'connection' => {
            'subdomain' => 'test',
            'domain' => 'example.com'
          }
        }
      end

      it 'is valid' do
        validator = described_class.new(valid_config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when config has invalid Liquid syntax' do
      let(:config_with_bad_syntax) do
        {
          'liquid_templates' => {
            'group_by' => '{{row.category' # Missing closing braces
          }
        }
      end

      it 'is invalid' do
        validator = described_class.new(config_with_bad_syntax)
        expect(validator.valid?).to be false
        expect(validator.errors.first).to include('invalid Liquid syntax in workflow.liquid_templates.group_by')
      end
    end
  end
end

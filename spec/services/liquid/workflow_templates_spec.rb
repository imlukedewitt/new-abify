# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Liquid::WorkflowTemplates do
  describe '#initialize' do
    it 'parses valid templates without error' do
      templates = {
        'group_by' => '{{row.organization}}',
        'sort_by' => '{{row.priority}}'
      }

      expect { described_class.new(templates) }.not_to raise_error
    end

    it 'raises Liquid::SyntaxError for invalid group_by syntax' do
      templates = {
        'group_by' => '{{row.organization'
      }

      expect { described_class.new(templates) }.to raise_error(Liquid::SyntaxError)
    end

    it 'raises Liquid::SyntaxError for invalid sort_by syntax' do
      templates = {
        'sort_by' => '{{row.priority'
      }

      expect { described_class.new(templates) }.to raise_error(Liquid::SyntaxError)
    end

    it 'handles nil liquid_templates' do
      expect { described_class.new(nil) }.not_to raise_error
    end

    it 'handles empty liquid_templates' do
      expect { described_class.new({}) }.not_to raise_error
    end
  end

  describe '#group_key' do
    it 'returns nil when no group_by is configured' do
      templates = {}
      workflow_templates = described_class.new(templates)

      expect(workflow_templates.group_key({})).to be_nil
    end

    it 'renders the group_by template with context' do
      templates = { 'group_by' => '{{row.organization}}' }
      workflow_templates = described_class.new(templates)
      context = { 'row' => { 'organization' => 'Acme Corp' } }

      expect(workflow_templates.group_key(context)).to eq('Acme Corp')
    end

    it 'handles symbol keys in context' do
      templates = { 'group_by' => '{{row.organization}}' }
      workflow_templates = described_class.new(templates)
      context = { row: { organization: 'Acme Corp' } }

      expect(workflow_templates.group_key(context)).to eq('Acme Corp')
    end

    it 'handles nested data access' do
      templates = { 'group_by' => '{{row.customer.type}}' }
      workflow_templates = described_class.new(templates)
      context = { 'row' => { 'customer' => { 'type' => 'enterprise' } } }

      expect(workflow_templates.group_key(context)).to eq('enterprise')
    end
  end

  describe '#sort_key' do
    it 'returns nil when no sort_by is configured' do
      templates = {}
      workflow_templates = described_class.new(templates)

      expect(workflow_templates.sort_key({})).to be_nil
    end

    it 'renders the sort_by template with context' do
      templates = { 'sort_by' => '{{row.priority}}' }
      workflow_templates = described_class.new(templates)
      context = { 'row' => { 'priority' => '1' } }

      expect(workflow_templates.sort_key(context)).to eq('1')
    end

    it 'handles complex sort expressions' do
      templates = { 'sort_by' => '{{row.last_name}}-{{row.first_name}}' }
      workflow_templates = described_class.new(templates)
      context = { 'row' => { 'first_name' => 'John', 'last_name' => 'Doe' } }

      expect(workflow_templates.sort_key(context)).to eq('Doe-John')
    end
  end

  describe 'custom filters' do
    it 'supports present? filter' do
      templates = { 'group_by' => '{{row.org | present?}}' }
      workflow_templates = described_class.new(templates)

      context = { 'row' => { 'org' => 'Acme' } }
      expect(workflow_templates.group_key(context)).to eq('true')

      context = { 'row' => { 'org' => '' } }
      expect(workflow_templates.group_key(context)).to eq('false')
    end

    it 'supports blank? filter' do
      templates = { 'group_by' => '{{row.org | blank?}}' }
      workflow_templates = described_class.new(templates)

      context = { 'row' => { 'org' => '' } }
      expect(workflow_templates.group_key(context)).to eq('true')
    end
  end
end


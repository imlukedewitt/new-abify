# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Liquid::StepTemplates do
  describe '#initialize' do
    it 'parses valid templates without error' do
      templates = {
        'url' => 'https://api.example.com/{{row.id}}',
        'method' => 'post',
        'body' => '{"name": "{{row.name}}"}'
      }

      expect { described_class.new(templates) }.not_to raise_error
    end

    it 'raises Liquid::SyntaxError for invalid template syntax' do
      templates = {
        'url' => 'https://api.example.com/{{row.id',
        'method' => 'get'
      }

      expect { described_class.new(templates) }.to raise_error(Liquid::SyntaxError)
    end

    it 'raises error for invalid syntax in nested success_data templates' do
      templates = {
        'url' => 'https://api.example.com',
        'method' => 'get',
        'success_data' => {
          'customer_id' => '{{response.customer.id',
          'name' => '{{response.name}}'
        }
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

  describe '#render_request' do
    let(:templates) do
      {
        'url' => 'https://{{subdomain}}.example.com/api/{{row.resource}}',
        'method' => 'post',
        'body' => '{"id": "{{row.id}}", "name": "{{row.name}}"}',
        'params' => 'limit={{row.limit}}'
      }
    end

    let(:context) do
      {
        'subdomain' => 'acme',
        'row' => {
          'resource' => 'users',
          'id' => '123',
          'name' => 'John',
          'limit' => '50'
        }
      }
    end

    it 'renders all request fields with context' do
      step_templates = described_class.new(templates)
      result = step_templates.render_request(context)

      expect(result[:url]).to eq('https://acme.example.com/api/users')
      expect(result[:method]).to eq('post')
      expect(result[:body]).to eq('{"id": "123", "name": "John"}')
      expect(result[:params]).to eq('limit=50')
    end

    it 'omits nil values for missing templates' do
      partial_templates = { 'url' => 'https://example.com', 'method' => 'get' }
      step_templates = described_class.new(partial_templates)
      result = step_templates.render_request(context)

      expect(result.keys).to contain_exactly(:url, :method)
      expect(result[:body]).to be_nil
      expect(result[:params]).to be_nil
    end

    it 'handles symbol keys in context' do
      step_templates = described_class.new(templates)
      symbol_context = {
        subdomain: 'acme',
        row: { resource: 'users', id: '123', name: 'John', limit: '50' }
      }
      result = step_templates.render_request(symbol_context)

      expect(result[:url]).to eq('https://acme.example.com/api/users')
    end
  end

  describe '#skip?' do
    it 'returns false when no skip_condition is configured' do
      templates = { 'url' => 'https://example.com' }
      step_templates = described_class.new(templates)

      expect(step_templates.skip?({})).to be false
    end

    it 'returns true when skip_condition evaluates to true' do
      templates = {
        'url' => 'https://example.com',
        'skip_condition' => '{{row.email | present?}}'
      }
      step_templates = described_class.new(templates)
      context = { 'row' => { 'email' => 'test@example.com' } }

      expect(step_templates.skip?(context)).to be true
    end

    it 'returns false when skip_condition evaluates to false' do
      templates = {
        'url' => 'https://example.com',
        'skip_condition' => '{{row.email | blank?}}'
      }
      step_templates = described_class.new(templates)
      context = { 'row' => { 'email' => 'test@example.com' } }

      expect(step_templates.skip?(context)).to be false
    end
  end

  describe '#required?' do
    it 'returns false when no required is configured' do
      templates = { 'url' => 'https://example.com' }
      step_templates = described_class.new(templates)

      expect(step_templates.required?({})).to be false
    end

    it 'returns true when required evaluates to true' do
      templates = {
        'url' => 'https://example.com',
        'required' => '{{row.organization | present?}}'
      }
      step_templates = described_class.new(templates)
      context = { 'row' => { 'organization' => 'Acme Corp' } }

      expect(step_templates.required?(context)).to be true
    end

    it 'returns false when required evaluates to false' do
      templates = {
        'url' => 'https://example.com',
        'required' => '{{row.organization | present?}}'
      }
      step_templates = described_class.new(templates)
      context = { 'row' => {} }

      expect(step_templates.required?(context)).to be false
    end
  end

  describe '#extract_success_data' do
    it 'returns empty hash when no success_data configured' do
      templates = { 'url' => 'https://example.com' }
      step_templates = described_class.new(templates)

      expect(step_templates.extract_success_data({})).to eq({})
    end

    it 'renders each template in success_data hash' do
      templates = {
        'url' => 'https://example.com',
        'success_data' => {
          'customer_id' => '{{response.customer.id}}',
          'name' => '{{response.customer.name}}'
        }
      }
      step_templates = described_class.new(templates)
      context = {
        'response' => {
          'customer' => { 'id' => '123', 'name' => 'John Doe' }
        }
      }

      result = step_templates.extract_success_data(context)

      expect(result['customer_id']).to eq('123')
      expect(result['name']).to eq('John Doe')
    end

    it 'handles array access in success_data templates' do
      templates = {
        'url' => 'https://example.com',
        'success_data' => {
          'first_id' => '{{response.items[0].id}}'
        }
      }
      step_templates = described_class.new(templates)
      context = {
        'response' => {
          'items' => [{ 'id' => 'first' }, { 'id' => 'second' }]
        }
      }

      result = step_templates.extract_success_data(context)

      expect(result['first_id']).to eq('first')
    end
  end

  describe 'custom filters' do
    it 'supports present? filter' do
      templates = { 'skip_condition' => '{{row.value | present?}}' }
      step_templates = described_class.new(templates)

      context = { 'row' => { 'value' => 'hello' } }
      expect(step_templates.skip?(context)).to be true

      context = { 'row' => { 'value' => '' } }
      expect(step_templates.skip?(context)).to be false
    end

    it 'supports blank? filter' do
      templates = { 'skip_condition' => '{{row.value | blank?}}' }
      step_templates = described_class.new(templates)

      context = { 'row' => { 'value' => '' } }
      expect(step_templates.skip?(context)).to be true

      context = { 'row' => { 'value' => 'hello' } }
      expect(step_templates.skip?(context)).to be false
    end
  end
end

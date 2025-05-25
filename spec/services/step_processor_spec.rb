# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepProcessor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:workflow_step, workflow: workflow) }
  let(:row) { create(:row) }
  let(:on_complete) { -> { puts 'done' } }
  let(:step_processor) { described_class.new(step, row, on_complete: on_complete) }
  let(:hydra_manager) { instance_double(HydraManager) }

  before { allow(HydraManager).to receive(:instance).and_return(hydra_manager) }

  describe '#initialize' do
    it 'assigns the class variables' do
      expect(step_processor.step).to eq(step)
      expect(step_processor.row).to eq(row)
      expect(step_processor.config).to eq(step.config.with_indifferent_access)
      expect(step_processor.instance_variable_get(:@hydra_manager)).to eq(hydra_manager)
      expect(step_processor.instance_variable_get(:@on_complete)).to eq(on_complete)
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, row) }.to raise_error(ArgumentError)
    end

    it 'raises an error when row is nil' do
      expect { described_class.new(step, nil) }.to raise_error(ArgumentError)
    end
  end

  describe '::call' do
    it 'initializes a new instance and calls execute' do
      step = create(:workflow_step)
      row = create(:row)
      expect(described_class).to receive(:new)
        .with(step, row)
        .and_return(step_processor)
      expect(step_processor).to receive(:call)
      described_class.call(step, row)
    end
  end

  describe '#call' do
    let(:callback_spy) { spy('callback') }

    it 'queues request and sets up callback properly' do
      processor = described_class.new(step, row, on_complete: callback_spy)
      request_fields = {
        url: 'https://subdomain.domain.com/customers.json',
        method: 'post',
        body: '{"customer":{"first_name":"John","last_name":"Doe","email":"john-doe@example.email"}}'
      }

      allow(processor).to receive(:render_request_fields).and_return(request_fields)

      expect(hydra_manager).to receive(:queue) do |args|
        response = double('response', code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call).once
    end

    it 'handles nil on_complete gracefully' do
      processor = described_class.new(step, row) # No callback provided
      allow(processor).to receive(:render_request_fields)
        .and_return({
                      url: 'https://test.com',
                      method: 'post'
                    })

      expect(hydra_manager).to receive(:queue) do |args|
        response = double('response', code: 200)
        expect { args[:on_complete].call(response) }.not_to raise_error
      end

      processor.call
    end
  end

  describe '#should_skip?' do
    it 'returns false when no skip_condition is configured' do
      expect(step_processor.send(:should_skip?)).to be false
    end

    it 'evaluates skip_condition and returns boolean result' do
      step.config = {
        'liquid_templates' => {
          'skip_condition' => "{{row.email | present?}}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:should_skip?)).to be true
    end

    it 'returns false when skip_condition evaluates to false' do
      step.config = {
        'liquid_templates' => {
          'skip_condition' => "{{row.email | blank?}}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:should_skip?)).to be false
    end
  end

  describe '#required?' do
    it 'returns false when no required_condition is configured' do
      expect(step_processor.send(:required?)).to be false
    end

    it 'evaluates required_condition and returns boolean result' do
      step.config = {
        'liquid_templates' => {
          'required_condition' => "{{row.organization | present?}}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:required?)).to be true
    end

    it 'returns false when required_condition evaluates to false' do
      step.config = {
        'liquid_templates' => {
          'required_condition' => "{{row.missing_field | present?}}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:required?)).to be false
    end
  end

  describe '#evaluate_boolean_condition' do
    it 'returns false when condition is not configured' do
      expect(step_processor.send(:evaluate_boolean_condition, 'nonexistent_condition')).to be false
    end

    it 'evaluates condition and returns boolean result' do
      step.config = {
        'liquid_templates' => {
          'test_condition' => "{{row.first_name | present?}}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:evaluate_boolean_condition, 'test_condition')).to be true
    end

    it 'handles complex boolean expressions' do
      step.config = {
        'liquid_templates' => {
          'complex_condition' => "{% if row.email contains '@' and row.organization %}true{% else %}false{% endif %}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:evaluate_boolean_condition, 'complex_condition')).to be true
    end
  end

  describe '#render_template_field' do
    it 'processes URL with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'url' => 'https://api.example.com/users/{{row.first_name}}/{{row.last_name}}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:render_template_field, 'url')).to eq('https://api.example.com/users/John/Doe')
    end

    it 'handles missing variables in URL template' do
      step.config = {
        'liquid_templates' => {
          'url' => 'https://api.example.com/users/{{row.missing_field}}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:render_template_field, 'url')).to eq('https://api.example.com/users/')
    end

    it 'processes method with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'method' => '{{ row.http_method | default: "get" }}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:render_template_field, 'method')).to eq('get')

      # Create a new row with updated data
      updated_row = create(:row, data: row.data.merge('http_method' => 'post'))
      step_processor = StepProcessor.new(step, updated_row)
      expect(step_processor.send(:render_template_field, 'method')).to eq('post')
    end

    it 'processes body with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'body' => '{"user":{"name":"{{row.first_name}} {{row.last_name}}","organization":"{{row.organization}}"}}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:render_template_field,
                                 'body')).to eq('{"user":{"name":"John Doe","organization":"Acme Corp"}}')
    end

    it 'processes params with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'params' => '{"email":"{{row.email}}","reference":"{{row.reference | default: "unknown"}}"}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:render_template_field,
                                 'params')).to eq('{"email":"john.doe@example.com","reference":"unknown"}')
    end

    it 'returns nil when template field is not configured' do
      step.config = { 'liquid_templates' => { 'url' => 'https://example.com' } }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:render_template_field, 'nonexistent')).to be_nil
    end
  end

  describe '#render_request_fields' do
    it 'processes all configured template fields for a request' do
      step.config = {
        'liquid_templates' => {
          'url' => 'https://api.example.com/users/{{row.first_name}}',
          'method' => '{{row.http_method | default: "post"}}',
          'body' => '{"name":"{{row.first_name}} {{row.last_name}}"}',
          'params' => '{"email":"{{row.email}}"}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      result = step_processor.send(:render_request_fields)

      expect(result[:url]).to eq('https://api.example.com/users/John')
      expect(result[:method]).to eq('post')
      expect(result[:body]).to eq('{"name":"John Doe"}')
      expect(result[:params]).to eq('{"email":"john.doe@example.com"}')
    end

    it 'only includes fields that are configured' do
      step.config = {
        'liquid_templates' => {
          'url' => 'https://api.example.com/users',
          'method' => 'get'
        }
      }
      step_processor = StepProcessor.new(step, row)

      result = step_processor.send(:render_request_fields)

      expect(result).to include(:url, :method)
      expect(result).not_to include(:body, :params)
    end

    it 'returns an empty hash when no liquid_templates are configured' do
      step.config = {}
      step_processor = StepProcessor.new(step, row)

      result = step_processor.send(:render_request_fields)

      expect(result).to eq({})
    end
  end
end

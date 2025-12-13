# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepExecutor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:step, workflow: workflow) }
  let(:row) { create(:row) }
  let(:step_templates) { build_step_templates_for(step) }
  let(:hydra_manager) { instance_double(HydraManager) }

  before { allow(HydraManager).to receive(:instance).and_return(hydra_manager) }

  def step_with_config(liquid_templates)
    step.update(config: { 'liquid_templates' => liquid_templates })
    build_step_templates_for(step)
  end

  def success_response(body = '{}')
    double('Response', body: body, code: 200)
  end

  def error_response(code, body = '{}')
    double('Response', body: body, code: code)
  end

  describe '#initialize' do
    it 'creates a new instance with step and row' do
      processor = described_class.new(step, row, step_templates: step_templates)
      expect(processor.step).to eq(step)
      expect(processor.row).to eq(row)
      expect(processor.config).to eq(step.config.with_indifferent_access)
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, row, step_templates: step_templates) }
        .to raise_error(ArgumentError, 'step is required')
    end

    it 'raises an error when row is nil' do
      expect { described_class.new(step, nil, step_templates: step_templates) }
        .to raise_error(ArgumentError, 'row is required')
    end

    it 'creates a StepExecution' do
      processor = described_class.new(step, row, step_templates: step_templates)
      expect(processor.execution).to be_a(StepExecution)
      expect(processor.execution.step).to eq(step)
      expect(processor.execution.row).to eq(row)
    end

    context 'with priority option' do
      it 'accepts priority: true' do
        processor = described_class.new(step, row, step_templates: step_templates, priority: true)
        expect(processor).to be_a(StepExecutor)
      end

      it 'accepts priority: false' do
        processor = described_class.new(step, row, step_templates: step_templates, priority: false)
        expect(processor).to be_a(StepExecutor)
      end
    end
  end

  describe '#call' do
    it 'queues a request with hydra manager' do
      templates = step_with_config('url' => 'https://api.example.com/test', 'method' => 'get')

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://api.example.com/test')
        expect(args[:method]).to eq('get')
        expect(args[:on_complete]).to be_a(Proc)
      end

      described_class.new(step, row, step_templates: templates).call
    end

    it 'processes successful response with success_data extraction' do
      templates = step_with_config(
        'url' => 'https://api.example.com',
        'method' => 'get',
        'success_data' => { 'customer_id' => '{{response.customer.id}}' }
      )

      callback_spy = spy('callback')
      processor = described_class.new(step, row, step_templates: templates, on_complete: callback_spy)

      allow(hydra_manager).to receive(:queue) do |args|
        args[:on_complete].call(success_response('{"customer":{"id":"123"}}'))
      end

      processor.call

      expect(callback_spy).to have_received(:call).with(success: true, data: { 'customer_id' => '123' })
    end

    it 'processes failed responses' do
      templates = step_with_config('url' => 'https://api.example.com', 'method' => 'get')

      callback_spy = spy('callback')
      processor = described_class.new(step, row, step_templates: templates, on_complete: callback_spy)

      allow(hydra_manager).to receive(:queue) do |args|
        args[:on_complete].call(error_response(404, '{"error":"Not found"}'))
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: false, error: "Request failed with status 404")
    end

    it 'handles invalid JSON responses' do
      templates = step_with_config('url' => 'https://api.example.com', 'method' => 'get')

      callback_spy = spy('callback')
      processor = described_class.new(step, row, step_templates: templates, on_complete: callback_spy)

      allow(hydra_manager).to receive(:queue) do |args|
        args[:on_complete].call(success_response('not json'))
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: false, error: "Invalid JSON response")
    end

    it 'handles nil on_complete gracefully' do
      templates = step_with_config('url' => 'https://test.com', 'method' => 'post')

      processor = described_class.new(step, row, step_templates: templates)

      allow(hydra_manager).to receive(:queue) do |args|
        expect { args[:on_complete].call(success_response) }.not_to raise_error
      end

      processor.call
    end

    it 'queues request with priority when priority flag is true' do
      templates = step_with_config('url' => 'https://priority.example.com/test', 'method' => 'post')

      processor = described_class.new(step, row, step_templates: templates, priority: true)

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:front]).to be true
      end

      processor.call
    end

    it 'uses connection fields in URL templates' do
      user = create(:user)
      connection = create(:connection, user: user, subdomain: 'acme', domain: 'my-app.io')
      workflow_with_connection = create(:workflow, connection: connection)
      step_with_connection = create(:step, workflow: workflow_with_connection, config: {
                                      'liquid_templates' => {
                                        'name' => 'Connection Test',
                                        'url' => 'https://{{subdomain}}.{{domain}}/api/v1/users',
                                        'method' => 'get'
                                      }
                                    })
      templates = build_step_templates_for(step_with_connection)

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://acme.my-app.io/api/v1/users')
      end

      described_class.new(step_with_connection, row, step_templates: templates).call
    end

    it 'uses connection base_url in templates' do
      user = create(:user)
      connection = create(:connection, user: user, subdomain: 'mycompany', domain: 'salesforce.com')
      workflow_with_connection = create(:workflow, connection: connection)
      step_with_connection = create(:step, workflow: workflow_with_connection, config: {
                                      'liquid_templates' => {
                                        'name' => 'Base URL Test',
                                        'url' => '{{base_url}}/services/data/v57.0/sobjects/Account',
                                        'method' => 'get'
                                      }
                                    })
      templates = build_step_templates_for(step_with_connection)

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://mycompany.salesforce.com/services/data/v57.0/sobjects/Account')
      end

      described_class.new(step_with_connection, row, step_templates: templates).call
    end

    it 'renders Liquid templates with row data' do
      templates = step_with_config(
        'url' => 'https://api.example.com/users/{{row.first_name}}',
        'method' => 'post',
        'body' => '{"name":"{{row.first_name}} {{row.last_name}}"}'
      )

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://api.example.com/users/John')
        expect(args[:body]).to eq('{"name":"John Doe"}')
      end

      described_class.new(step, row, step_templates: templates).call
    end
  end

  describe '#should_skip?' do
    it 'returns false when no skip_condition is configured' do
      processor = described_class.new(step, row, step_templates: step_templates)
      expect(processor.should_skip?).to be false
    end

    it 'evaluates skip_condition and returns true when condition is met' do
      templates = step_with_config('skip_condition' => '{{row.email | present?}}')
      processor = described_class.new(step, row, step_templates: templates)

      expect(processor.should_skip?).to be true
    end

    it 'returns false when skip_condition evaluates to false' do
      templates = step_with_config('skip_condition' => '{{row.email | blank?}}')
      processor = described_class.new(step, row, step_templates: templates)

      expect(processor.should_skip?).to be false
    end
  end

  describe '#required?' do
    it 'returns false when no required is configured' do
      templates = step_with_config({})
      processor = described_class.new(step, row, step_templates: templates)
      expect(processor.required?).to be false
    end

    it 'evaluates required and returns true when condition is met' do
      templates = step_with_config('required' => '{{row.organization | present?}}')
      processor = described_class.new(step, row, step_templates: templates)

      expect(processor.required?).to be true
    end

    it 'returns false when required evaluates to false' do
      templates = step_with_config('required' => '{{row.missing_field | present?}}')
      processor = described_class.new(step, row, step_templates: templates)

      expect(processor.required?).to be false
    end
  end
end

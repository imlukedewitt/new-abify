# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepExecutor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:step, workflow: workflow) }
  let(:row) { create(:row) }
  let(:hydra_manager) { instance_double(HydraManager) }

  before { allow(HydraManager).to receive(:instance).and_return(hydra_manager) }

  describe '#initialize' do
    it 'creates a new instance with step and row' do
      processor = described_class.new(step, row)
      expect(processor.step).to eq(step)
      expect(processor.row).to eq(row)
      expect(processor.config).to eq(step.config.with_indifferent_access)
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, row) }.to raise_error(ArgumentError, 'step is required')
    end

    it 'raises an error when row is nil' do
      expect { described_class.new(step, nil) }.to raise_error(ArgumentError, 'row is required')
    end

    it 'creates a StepExecution' do
      processor = described_class.new(step, row)
      expect(processor.execution).to be_a(StepExecution)
      expect(processor.execution.step).to eq(step)
      expect(processor.execution.row).to eq(row)
    end

    context 'with priority option' do
      it 'accepts priority: true' do
        processor = described_class.new(step, row, priority: true)
        expect(processor).to be_a(StepExecutor)
      end

      it 'accepts priority: false' do
        processor = described_class.new(step, row, priority: false)
        expect(processor).to be_a(StepExecutor)
      end
    end
  end

  describe '::call' do
    it 'initializes a new instance and calls it' do
      processor = instance_double(StepExecutor)
      expect(described_class).to receive(:new).with(step, row).and_return(processor)
      expect(processor).to receive(:call)
      described_class.call(step, row)
    end
  end

  describe '#call' do
    it 'queues a request with hydra manager' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://api.example.com/test',
                      'method' => 'get'
                    }
                  })

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://api.example.com/test')
        expect(args[:method]).to eq('get')
        expect(args[:on_complete]).to be_a(Proc)
      end

      described_class.new(step, row).call
    end

    it 'processes successful response with success_data extraction' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://api.example.com',
                      'method' => 'get',
                      'success_data' => {
                        'customer_id' => '{{response.customer.id}}'
                      }
                    }
                  })

      callback_spy = spy('callback')
      processor = described_class.new(step, row, on_complete: callback_spy)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{"customer":{"id":"123"}}', code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call).with(success: true, data: { 'customer_id' => '123' })
    end

    it 'processes failed responses' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://api.example.com',
                      'method' => 'get'
                    }
                  })

      callback_spy = spy('callback')
      processor = described_class.new(step, row, on_complete: callback_spy)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{"error":"Not found"}', code: 404)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: false, error: "Request failed with status 404")
    end

    it 'handles invalid JSON responses' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://api.example.com',
                      'method' => 'get'
                    }
                  })

      callback_spy = spy('callback')
      processor = described_class.new(step, row, on_complete: callback_spy)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: 'not json', code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: false, error: "Invalid JSON response")
    end

    it 'handles nil on_complete gracefully' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://test.com',
                      'method' => 'post'
                    }
                  })

      processor = described_class.new(step, row)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{}', code: 200)
        expect { args[:on_complete].call(response) }.not_to raise_error
      end

      processor.call
    end

    it 'queues request with priority when priority flag is true' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://priority.example.com/test',
                      'method' => 'post'
                    }
                  })

      processor = described_class.new(step, row, priority: true)

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

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://acme.my-app.io/api/v1/users')
      end

      described_class.new(step_with_connection, row).call
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

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://mycompany.salesforce.com/services/data/v57.0/sobjects/Account')
      end

      described_class.new(step_with_connection, row).call
    end

    it 'renders Liquid templates with row data' do
      step.update(config: {
                    'liquid_templates' => {
                      'url' => 'https://api.example.com/users/{{row.first_name}}',
                      'method' => 'post',
                      'body' => '{"name":"{{row.first_name}} {{row.last_name}}"}'
                    }
                  })

      expect(hydra_manager).to receive(:queue) do |args|
        expect(args[:url]).to eq('https://api.example.com/users/John')
        expect(args[:body]).to eq('{"name":"John Doe"}')
      end

      described_class.new(step, row).call
    end
  end

  describe '#should_skip?' do
    it 'returns false when no skip_condition is configured' do
      processor = described_class.new(step, row)
      expect(processor.should_skip?).to be false
    end

    it 'evaluates skip_condition and returns true when condition is met' do
      step.update(config: {
                    'liquid_templates' => {
                      'skip_condition' => "{{row.email | present?}}"
                    }
                  })
      processor = described_class.new(step, row)

      expect(processor.should_skip?).to be true
    end

    it 'returns false when skip_condition evaluates to false' do
      step.update(config: {
                    'liquid_templates' => {
                      'skip_condition' => "{{row.email | blank?}}"
                    }
                  })
      processor = described_class.new(step, row)

      expect(processor.should_skip?).to be false
    end
  end

  describe '#required?' do
    it 'returns false when no required is configured' do
      step.update(config: { 'liquid_templates' => {} })
      processor = described_class.new(step, row)
      expect(processor.required?).to be false
    end

    it 'evaluates required and returns true when condition is met' do
      step.update(config: {
                    'liquid_templates' => {
                      'required' => "{{row.organization | present?}}"
                    }
                  })
      processor = described_class.new(step, row)

      expect(processor.required?).to be true
    end

    it 'returns false when required evaluates to false' do
      step.update(config: {
                    'liquid_templates' => {
                      'required' => "{{row.missing_field | present?}}"
                    }
                  })
      processor = described_class.new(step, row)

      expect(processor.required?).to be false
    end
  end
end

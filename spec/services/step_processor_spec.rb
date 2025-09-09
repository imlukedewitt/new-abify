# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepProcessor do
  let(:auth_config) { { type: :basic, username: 'abc123', password: 'x' } }
  let(:workflow) { create(:workflow) }
  let(:step) { create(:step, workflow: workflow) }
  let(:row) { create(:row) }
  let(:on_complete) { -> { puts 'done' } }
  let(:hydra_manager) { instance_double(HydraManager) }
  let(:default_options) { { on_complete: on_complete, auth_config: auth_config, hydra_manager: hydra_manager } }
  let(:step_processor) { described_class.new(step, row, **default_options) }

  before { allow(HydraManager).to receive(:instance).and_return(hydra_manager) }

  describe '#initialize' do
    it 'assigns the class variables' do
      expect(step_processor.step).to eq(step)
      expect(step_processor.row).to eq(row)
      expect(step_processor.config).to eq(step.config.with_indifferent_access)
      expect(step_processor.instance_variable_get(:@hydra_manager)).to eq(hydra_manager)
      expect(step_processor.instance_variable_get(:@on_complete)).to eq(on_complete)
      expect(step_processor.instance_variable_get(:@auth_config)).to eq(auth_config)
      expect(step_processor.instance_variable_get(:@priority)).to be false
    end

    context 'with priority option' do
      it 'initializes with priority true when specified' do
        processor_with_priority = described_class.new(step, row, **default_options, priority: true)
        expect(processor_with_priority.instance_variable_get(:@priority)).to be true
      end

      it 'initializes with priority false when specified' do
        processor_with_priority = described_class.new(step, row, **default_options, priority: false)
        expect(processor_with_priority.instance_variable_get(:@priority)).to be false
      end
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, row) }.to raise_error(ArgumentError)
    end

    it 'raises an error when row is nil' do
      expect { described_class.new(step, nil) }.to raise_error(ArgumentError)
    end

    context 'with auth configuration' do
      it 'prioritizes explicitly passed auth_config' do
        explicit_auth = { type: :custom, token: 'explicit_token' }
        processor = described_class.new(step, row, auth_config: explicit_auth)
        expect(processor.instance_variable_get(:@auth_config)).to eq(explicit_auth)
      end

      it 'falls back to workflow config auth when no step auth config is available' do
        workflow_with_auth = create(
          :workflow, config: {
            'connection' => {
              'auth' => { 'type' => 'oauth', 'token' => 'workflow_token' }
            }
          }
        )
        step_without_auth = create(:step, workflow: workflow_with_auth)
        processor = described_class.new(step_without_auth, row)
        expect(processor.instance_variable_get(:@auth_config)).to eq({ 'type' => 'oauth', 'token' => 'workflow_token' })
      end

      it 'defaults to empty hash when no auth config is available anywhere' do
        workflow_without_auth = create(:workflow, config: { 'connection' => {} })
        step_without_auth = create(:step, workflow: workflow_without_auth)
        processor = described_class.new(step_without_auth, row)
        expect(processor.instance_variable_get(:@auth_config)).to eq({})
      end
    end
  end

  describe '::call' do
    it 'initializes a new instance and calls execute' do
      step = create(:step)
      row = create(:row)
      expect(described_class).to receive(:new)
        .with(step, row)
        .and_return(step_processor)
      expect(step_processor).to receive(:call)
      described_class.call(step, row)
    end
  end

  describe '#call' do
    it 'queues request and sets up callback properly' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Test Step',
                             'url' => 'https://api.example.com/test',
                             'method' => 'get',
                             'success_data' => {} # Ensure no success data is processed
                           }
                         })
      callback_spy = spy('callback')
      processor = described_class.new(test_step, row, on_complete: callback_spy, auth_config: auth_config)

      request_fields = processor.send(:render_request_fields)

      expect(hydra_manager).to receive(:queue)
        .with(
          hash_including(
            **request_fields,
            auth_config: auth_config,
            front: false,
            on_complete: kind_of(Proc)
          )
        ) do |args|
          response = double('response', body: '{}', code: 200)
          args[:on_complete].call(response)
          double('Typhoeus::Request')
        end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: true, data: {})
    end

    it 'queues request with front: true when priority is true' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Priority Step',
                             'url' => 'https://priority.example.com/test',
                             'method' => 'post'
                           }
                         })
      callback_spy = spy('callback')
      processor = described_class.new(test_step, row, **default_options.except(:hydra_manager),
        on_complete: callback_spy, auth_config: auth_config, priority: true)

      request_fields = processor.send(:render_request_fields)

      expect(hydra_manager).to receive(:queue)
        .with(
          hash_including(
            **request_fields,
            auth_config: auth_config,
            front: true,
            on_complete: kind_of(Proc)
          )
        ) do |args|
          response = double('response', body: '{}', code: 200)
          args[:on_complete].call(response)
          double('Typhoeus::Request')
        end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: true, data: {})
    end

    it 'handles successful responses with success_data' do
      step.config = {
        'liquid_templates' => {
          'name' => 'Test Step',
          'url' => 'https://api.example.com',
          'method' => 'get',
          'success_data' => {
            'customer_id' => '{{response.customer.id}}'
          }
        }
      }
      callback_spy = spy('callback')
      processor = described_class.new(step, row, on_complete: callback_spy)

      expect(hydra_manager).to receive(:queue) do |args|
        response = double('response',
                          body: '{"customer":{"id":"123"}}',
                          code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: true, data: { 'customer_id' => '123' })
    end

    it 'handles failed responses' do
      step.config = {
        'liquid_templates' => {
          'name' => 'Test Step',
          'url' => 'https://api.example.com',
          'method' => 'get'
        }
      }
      callback_spy = spy('callback')
      processor = described_class.new(step, row, on_complete: callback_spy)

      expect(hydra_manager).to receive(:queue) do |args|
        response = double('response',
                          body: '{"error":"Not found"}',
                          code: 404)
        args[:on_complete].call(response)
        double('Typhoeus::Request')
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: false, error: "Request failed with status 404")
    end

    it 'handles invalid JSON responses' do
      step.config = {
        'liquid_templates' => {
          'name' => 'Test Step',
          'url' => 'https://api.example.com',
          'method' => 'get'
        }
      }
      callback_spy = spy('callback')
      processor = described_class.new(step, row, on_complete: callback_spy)

      expect(hydra_manager).to receive(:queue) do |args|
        response = double('response',
                          body: 'not json',
                          code: 200)
        args[:on_complete].call(response)
        double('Typhoeus::Request')
      end

      processor.call

      expect(callback_spy).to have_received(:call)
        .with(success: false, error: "Invalid JSON response")
    end

    it 'handles nil on_complete gracefully' do
      step.config = {
        'liquid_templates' => {
          'name' => 'Test Step',
          'url' => 'https://test.com',
          'method' => 'post'
        }
      }
      processor = described_class.new(step, row) # No callback provided

      expect(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{}', code: 200)
        expect { args[:on_complete].call(response) }.not_to raise_error
      end

      processor.call
    end
  end

  describe '#process_response' do
    let(:step) do
      create(:step, config: {
               'liquid_templates' => {
                 'name' => 'Test Step',
                 'url' => 'https://api.example.com'
               }
             })
    end
    let(:row) { create(:row) }
    let(:processor) { described_class.new(step, row) }

    it 'returns success result for 2xx responses' do
      response = double('response',
                        body: '{"data":"value"}',
                        code: 201)

      result = processor.send(:process_response, response)
      expect(result).to eq(success: true, data: {})
    end

    it 'extracts error message from response when available' do
      response = double('response',
                        body: '{"errors":"Something went wrong"}',
                        code: 422)

      result = processor.send(:process_response, response)
      expect(result).to eq(success: false, error: "Something went wrong")
    end

    it 'handles empty responses' do
      response = double('response',
                        body: '',
                        code: 204)

      result = processor.send(:process_response, response)
      expect(result).to eq(success: true, data: {})
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
    it 'returns false when no required is configured' do
      step.config = { 'liquid_templates' => {} }
      step_processor = StepProcessor.new(step, row)
      expect(step_processor.send(:required?)).to be false
    end

    it 'evaluates required and returns boolean result' do
      step.config = {
        'liquid_templates' => {
          'required' => "{{row.organization | present?}}"
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.send(:required?)).to be true
    end

    it 'returns false when required evaluates to false' do
      step.config = {
        'liquid_templates' => {
          'required' => "{{row.missing_field | present?}}"
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

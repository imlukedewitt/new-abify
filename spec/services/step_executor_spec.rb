# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepExecutor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:step, workflow: workflow) }
  let(:row) { create(:row) }
  let(:on_complete) { -> { puts 'done' } }
  let(:hydra_manager) { instance_double(HydraManager) }
  let(:default_options) { { on_complete: on_complete, hydra_manager: hydra_manager } }
  let(:step_processor) { described_class.new(step, row, **default_options) }

  before { allow(HydraManager).to receive(:instance).and_return(hydra_manager) }

  describe '#initialize' do
    it 'assigns step, row, and config' do
      expect(step_processor.step).to eq(step)
      expect(step_processor.row).to eq(row)
      expect(step_processor.config).to eq(step.config.with_indifferent_access)
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
    it 'queues request with correct parameters' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Test Step',
                             'url' => 'https://api.example.com/test',
                             'method' => 'get'
                           }
                         })
      callback_spy = spy('callback')
      processor = described_class.new(test_step, row, on_complete: callback_spy, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{}', code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(hydra_manager).to have_received(:queue).with(
        hash_including(url: 'https://api.example.com/test', method: 'get', front: false)
      )
      expect(callback_spy).to have_received(:call).with(success: true, data: {})
    end

    it 'queues with priority when priority flag is true' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Priority Step',
                             'url' => 'https://api.example.com',
                             'method' => 'post'
                           }
                         })
      processor = described_class.new(test_step, row, priority: true, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue)

      processor.call

      expect(hydra_manager).to have_received(:queue).with(hash_including(front: true))
    end

    it 'extracts success_data from response' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Extract Data Step',
                             'url' => 'https://api.example.com',
                             'method' => 'get',
                             'success_data' => {
                               'customer_id' => '{{response.customer.id}}'
                             }
                           }
                         })
      callback_spy = spy('callback')
      processor = described_class.new(test_step, row, on_complete: callback_spy, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{"customer":{"id":"123"}}', code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call).with(success: true, data: { 'customer_id' => '123' })
    end

    it 'handles failed responses' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Failed Step',
                             'url' => 'https://api.example.com',
                             'method' => 'get'
                           }
                         })
      callback_spy = spy('callback')
      processor = described_class.new(test_step, row, on_complete: callback_spy, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: '{"error":"Not found"}', code: 404)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call).with(success: false, error: "Request failed with status 404")
    end

    it 'handles invalid JSON responses' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Invalid JSON Step',
                             'url' => 'https://api.example.com',
                             'method' => 'get'
                           }
                         })
      callback_spy = spy('callback')
      processor = described_class.new(test_step, row, on_complete: callback_spy, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue) do |args|
        response = double('response', body: 'not json', code: 200)
        args[:on_complete].call(response)
      end

      processor.call

      expect(callback_spy).to have_received(:call).with(success: false, error: "Invalid JSON response")
    end

    it 'uses connection fields in URL templates' do
      user = create(:user)
      connection = create(:connection, user: user, subdomain: 'mycompany', domain: 'salesforce.com')
      workflow_with_connection = create(:workflow, connection: connection)
      test_step = create(:step, workflow: workflow_with_connection, config: {
                           'liquid_templates' => {
                             'name' => 'Connection Step',
                             'url' => '{{base_url}}/api/users'
                           }
                         })
      processor = described_class.new(test_step, row, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue)

      processor.call

      expect(hydra_manager).to have_received(:queue).with(
        hash_including(url: 'https://mycompany.salesforce.com/api/users')
      )
    end

    it 'skips request when skip_condition is true' do
      test_step = create(:step, config: {
                           'liquid_templates' => {
                             'name' => 'Skipped Step',
                             'url' => 'https://api.example.com',
                             'skip_condition' => '{{row.email | present?}}'
                           }
                         })
      processor = described_class.new(test_step, row, hydra_manager: hydra_manager)

      allow(hydra_manager).to receive(:queue)

      processor.call

      expect(hydra_manager).not_to have_received(:queue)
    end
  end
end

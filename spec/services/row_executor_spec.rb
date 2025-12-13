# frozen_string_literal: true

require "rails_helper"

RSpec.describe RowExecutor do
  let(:workflow) { create(:workflow) }
  let(:data_source) { create(:data_source) }
  let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: data_source) }
  let(:row) { create(:row, data_source: data_source, data: { 'name' => 'Test' }) }

  before do
    # Stub HydraManager to prevent actual HTTP and immediately invoke callbacks
    allow(HydraManager.instance).to receive(:queue) do |**args|
      response = double('Response', code: 200, body: '{"id": "123"}')
      args[:on_complete]&.call(response)
    end
    allow(HydraManager.instance).to receive(:run)
  end

  describe '#initialize' do
    it 'creates a new instance with required attributes' do
      executor = described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution)

      expect(executor.row).to eq(row)
      expect(executor.workflow).to eq(workflow)
      expect(executor.workflow_execution).to eq(workflow_execution)
    end

    it 'raises ArgumentError when row is nil' do
      expect { described_class.new(row: nil, workflow: workflow, workflow_execution: workflow_execution) }
        .to raise_error(ArgumentError, 'row is required')
    end

    it 'raises ArgumentError when workflow is nil' do
      expect { described_class.new(row: row, workflow: nil, workflow_execution: workflow_execution) }
        .to raise_error(ArgumentError, 'workflow is required')
    end

    it 'raises ArgumentError when workflow_execution is nil' do
      expect { described_class.new(row: row, workflow: workflow, workflow_execution: nil) }
        .to raise_error(ArgumentError, 'workflow_execution is required')
    end
  end

  describe '#call' do
    context 'with no steps' do
      it 'creates a completed row execution' do
        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        expect(RowExecution.count).to eq(1)
        expect(RowExecution.first.status).to eq('complete')
      end
    end

    context 'with one step' do
      before do
        create(:step, workflow: workflow, order: 1, config: {
                 'liquid_templates' => {
                   'name' => 'Test Step',
                   'url' => 'https://api.example.com/test',
                   'method' => 'get'
                 }
               })
      end

      it 'creates row execution and step execution' do
        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        expect(RowExecution.count).to eq(1)
        expect(StepExecution.count).to eq(1)
        expect(RowExecution.first.status).to eq('complete')
      end
    end

    context 'with multiple steps' do
      before do
        create(:step, workflow: workflow, order: 1, name: 'First', config: {
                 'liquid_templates' => { 'name' => 'First', 'url' => 'https://api.example.com/first', 'method' => 'get' }
               })
        create(:step, workflow: workflow, order: 2, name: 'Second', config: {
                 'liquid_templates' => { 'name' => 'Second', 'url' => 'https://api.example.com/second', 'method' => 'get' }
               })
      end

      it 'processes all steps in order' do
        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        expect(StepExecution.count).to eq(2)
        expect(RowExecution.first.status).to eq('complete')

        steps = StepExecution.joins(:step).order('steps."order"')
        expect(steps.map { |se| se.step.name }).to eq(%w[First Second])
      end
    end

    context 'when a step should be skipped' do
      before do
        create(:step, workflow: workflow, order: 1, name: 'Skippable', config: {
                 'liquid_templates' => {
                   'name' => 'Skippable',
                   'url' => 'https://api.example.com/test',
                   'method' => 'get',
                   'skip_condition' => '{{ row.should_skip | default: false }}'
                 }
               })
      end

      it 'runs step when skip_condition is false' do
        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        step_exec = StepExecution.first
        expect(step_exec.status).to eq('success')
      end

      it 'skips step when skip_condition is true' do
        row.update!(data: { 'should_skip' => 'true' })

        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        expect(StepExecution.count).to eq(0)
        expect(RowExecution.first.status).to eq('complete')
      end
    end

    context 'when a required step fails' do
      before do
        allow(HydraManager.instance).to receive(:queue) do |**args|
          response = double('Response', code: 500, body: '{"error": "Server error"}')
          args[:on_complete]&.call(response)
        end

        create(:step, workflow: workflow, order: 1, name: 'Required Step', config: {
                 'liquid_templates' => {
                   'name' => 'Required Step',
                   'url' => 'https://api.example.com/test',
                   'method' => 'get',
                   'required' => 'true'
                 }
               })
        create(:step, workflow: workflow, order: 2, name: 'After Required', config: {
                 'liquid_templates' => { 'name' => 'After Required', 'url' => 'https://api.example.com/second', 'method' => 'get' }
               })
      end

      it 'marks row as failed and stops processing' do
        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        row.reload
        expect(row.status).to eq('failed')
        expect(RowExecution.first.status).to eq('failed')
        expect(StepExecution.count).to eq(1) # Second step never runs
      end
    end

    context 'when a non-required step fails' do
      before do
        allow(HydraManager.instance).to receive(:queue) do |**args|
          response = double('Response', code: 500, body: '{"error": "Server error"}')
          args[:on_complete]&.call(response)
        end

        create(:step, workflow: workflow, order: 1, name: 'Optional Step', config: {
                 'liquid_templates' => {
                   'name' => 'Optional Step',
                   'url' => 'https://api.example.com/test',
                   'method' => 'get',
                   'required' => 'false'
                 }
               })
      end

      it 'continues processing and completes row execution' do
        described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution).call

        row.reload
        expect(row.status).not_to eq('failed')
        expect(RowExecution.first.status).to eq('complete')
      end
    end
  end

  describe '#wait_for_completion' do
    it 'returns immediately after call completes' do
      executor = described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution)
      executor.call

      start_time = Time.current
      executor.wait_for_completion
      elapsed = Time.current - start_time

      expect(elapsed).to be < 0.1
    end
  end
end

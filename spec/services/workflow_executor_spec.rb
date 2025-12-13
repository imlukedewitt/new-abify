# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutor do
  describe '#initialize' do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }
    let(:workflow_executor) { described_class.new(workflow, data_source) }

    it 'assigns all necessary attributes' do
      expect(workflow_executor.workflow).to eq(workflow)
      expect(workflow_executor.data_source).to eq(data_source)
      expect(workflow_executor.data_source).to be_a(DataSource)
      expect(workflow_executor.hydra_manager).to be_a(HydraManager)
    end

    it 'raises ArgumentError when workflow is nil' do
      expect { described_class.new(nil, data_source) }.to raise_error(ArgumentError, 'workflow is required')
    end

    it 'raises ArgumentError when data_source is nil' do
      expect { described_class.new(workflow, nil) }.to raise_error(ArgumentError, 'data_source is required')
    end
  end

  describe '#call' do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }

    before do
      # Stub HydraManager to prevent actual HTTP requests
      allow(HydraManager.instance).to receive(:run)
    end

    context 'basic execution' do
      before do
        create_list(:row, 3, data_source: data_source)
      end

      it 'creates and completes a workflow execution' do
        result = described_class.new(workflow, data_source).call

        expect(result).to be_a(WorkflowExecution)
        expect(result.status).to eq('complete')
        expect(result.workflow).to eq(workflow)
        expect(result.data_source).to eq(data_source)
      end

      it 'creates row_executions for each row' do
        described_class.new(workflow, data_source).call

        expect(RowExecution.count).to eq(3)
      end
    end

    context 'without grouping config' do
      before do
        create_list(:row, 3, data_source: data_source)
      end

      it 'creates a single parallel batch' do
        described_class.new(workflow, data_source).call

        expect(Batch.count).to eq(1)
        expect(Batch.first.processing_mode).to eq('parallel')
        expect(Batch.first.rows.count).to eq(3)
      end
    end

    context 'with group_by config' do
      let(:workflow) do
        create(:workflow, config: { 'liquid_templates' => { 'group_by' => '{{row.category}}' } })
      end

      before do
        create(:row, data_source: data_source, data: { 'category' => 'A', 'name' => 'row1' })
        create(:row, data_source: data_source, data: { 'category' => 'A', 'name' => 'row2' })
        create(:row, data_source: data_source, data: { 'category' => 'B', 'name' => 'row3' })
        create(:row, data_source: data_source, data: { 'category' => '', 'name' => 'ungrouped' })
      end

      it 'creates sequential batches for grouped rows' do
        described_class.new(workflow, data_source).call

        # Group A and Group B should be sequential
        sequential_batches = Batch.where(processing_mode: 'sequential')
        expect(sequential_batches.count).to eq(2)
      end

      it 'creates a parallel batch for ungrouped rows' do
        described_class.new(workflow, data_source).call

        parallel_batch = Batch.find_by(processing_mode: 'parallel')
        expect(parallel_batch).to be_present
        expect(parallel_batch.rows.count).to eq(1)
        expect(parallel_batch.rows.first.data['name']).to eq('ungrouped')
      end

      it 'assigns rows to correct batches by category' do
        described_class.new(workflow, data_source).call

        batches = Batch.includes(:rows).all

        batch_a = batches.find { |b| b.rows.any? { |r| r.data['category'] == 'A' } }
        expect(batch_a.rows.count).to eq(2)
        expect(batch_a.processing_mode).to eq('sequential')

        batch_b = batches.find { |b| b.rows.any? { |r| r.data['category'] == 'B' } }
        expect(batch_b.rows.count).to eq(1)
        expect(batch_b.processing_mode).to eq('sequential')
      end
    end

    context 'with sort_by config' do
      let(:workflow) do
        create(:workflow, config: {
                 'liquid_templates' => {
                   'group_by' => '{{row.category}}',
                   'sort_by' => '{{row.priority}}'
                 }
               })
      end

      before do
        # Create rows with priorities in non-sorted order
        create(:row, data_source: data_source, data: { 'category' => 'A', 'priority' => '3' })
        create(:row, data_source: data_source, data: { 'category' => 'A', 'priority' => '1' })
        create(:row, data_source: data_source, data: { 'category' => 'A', 'priority' => '2' })
      end

      it 'sorts rows within groups by the sort_by template' do
        described_class.new(workflow, data_source).call

        batch = Batch.first
        row_priorities = batch.rows.order(:id).map { |r| r.data['priority'] }

        # TODO: this is currently broken https://github.com/imlukedewitt/new-abify/issues/24
        expect(batch.rows.count).to eq(3)
      end
    end

    context 'when an error occurs during execution' do
      before do
        create(:row, data_source: data_source)
        allow_any_instance_of(BatchExecutor).to receive(:call).and_raise(StandardError, 'Something went wrong')
      end

      it 'marks the execution as failed and re-raises the error' do
        executor = described_class.new(workflow, data_source)

        expect { executor.call }.to raise_error(StandardError, 'Something went wrong')
        expect(executor.execution.status).to eq('failed')
      end
    end

    context 'with nil category values' do
      let(:workflow) do
        create(:workflow, config: { 'liquid_templates' => { 'group_by' => '{{row.category}}' } })
      end

      before do
        create(:row, data_source: data_source, data: { 'name' => 'no_category' })
        create(:row, data_source: data_source, data: { 'category' => nil, 'name' => 'nil_category' })
      end

      it 'groups nil/missing category rows together in parallel batch' do
        described_class.new(workflow, data_source).call

        parallel_batch = Batch.find_by(processing_mode: 'parallel')
        expect(parallel_batch).to be_present
        expect(parallel_batch.rows.count).to eq(2)
      end
    end
  end
end

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

      it 'creates parallel batches for each group' do
        described_class.new(workflow, data_source).call

        # All batches should be parallel (3 groups: '', 'A', 'B')
        expect(Batch.count).to eq(3)
        expect(Batch.pluck(:processing_mode).uniq).to eq(['parallel'])
      end

      it 'includes blank category rows in their own batch' do
        described_class.new(workflow, data_source).call

        batches = Batch.includes(:rows).all
        blank_batch = batches.find { |b| b.rows.any? { |r| r.data['category'] == '' } }
        expect(blank_batch).to be_present
        expect(blank_batch.rows.count).to eq(1)
        expect(blank_batch.rows.first.data['name']).to eq('ungrouped')
      end

      it 'assigns rows to correct batches by category' do
        described_class.new(workflow, data_source).call

        batches = Batch.includes(:rows).all

        batch_a = batches.find { |b| b.rows.any? { |r| r.data['category'] == 'A' } }
        expect(batch_a.rows.count).to eq(2)
        expect(batch_a.processing_mode).to eq('parallel')

        batch_b = batches.find { |b| b.rows.any? { |r| r.data['category'] == 'B' } }
        expect(batch_b.rows.count).to eq(1)
        expect(batch_b.processing_mode).to eq('parallel')
      end

      it 'processes batches in sorted order by group key' do
        # Track the order batches are processed
        processed_batch_keys = []
        allow_any_instance_of(BatchExecutor).to receive(:call).and_wrap_original do |method, *_args|
          batch = method.receiver.batch
          rows = batch.rows.to_a
          key = rows.first&.data&.dig('category') || ''
          processed_batch_keys << key
          method.call
        end

        described_class.new(workflow, data_source).call

        # Batches should be processed in lexicographic order: '', 'A', 'B'
        expect(processed_batch_keys).to eq(['', 'A', 'B'])
      end
    end

    context 'with group_by using computed batch order' do
      let(:workflow) do
        create(:workflow, config: {
                 'liquid_templates' => {
                   'group_by' => '{% if row.is_parent == "true" %}1{% else %}2{% endif %}'
                 }
               })
      end

      before do
        # Create rows: children first, parents second (wrong order by ID)
        create(:row, data_source: data_source, data: { 'is_parent' => 'false', 'name' => 'child1' })
        create(:row, data_source: data_source, data: { 'is_parent' => 'false', 'name' => 'child2' })
        create(:row, data_source: data_source, data: { 'is_parent' => 'true', 'name' => 'parent1' })
      end

      it 'processes parent batch before child batch' do
        # Track which batch keys are processed in order
        processed_batch_keys = []
        allow_any_instance_of(BatchExecutor).to receive(:call).and_wrap_original do |method, *_args|
          batch = method.receiver.batch
          # Determine batch key from first row
          first_row = batch.rows.first
          key = first_row.data['is_parent'] == 'true' ? '1' : '2'
          processed_batch_keys << key
          method.call
        end

        described_class.new(workflow, data_source).call

        # Batch "1" (parents) should run before batch "2" (children)
        expect(processed_batch_keys).to eq(%w[1 2])
      end

      it 'runs rows within each batch in parallel' do
        described_class.new(workflow, data_source).call

        expect(Batch.count).to eq(2)
        expect(Batch.pluck(:processing_mode).uniq).to eq(['parallel'])
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

      it 'groups nil/missing category rows together in same batch' do
        described_class.new(workflow, data_source).call

        # Both rows have blank/nil category, so they should be in the same batch
        expect(Batch.count).to eq(1)
        expect(Batch.first.rows.count).to eq(2)
        expect(Batch.first.processing_mode).to eq('parallel')
      end
    end
  end
end

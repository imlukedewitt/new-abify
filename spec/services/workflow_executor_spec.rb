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
  end

  describe '#call' do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }
    let(:workflow_executor) { described_class.new(workflow, data_source) }

    it 'creates and starts a workflow execution' do
      workflow_execution_double = instance_double(WorkflowExecution)

      expect(WorkflowExecution).to receive(:find_or_create_by)
        .with(workflow: workflow, data_source: data_source)
        .and_return(workflow_execution_double)

      expect(workflow_execution_double).to receive(:start!)

      result = workflow_executor.call
      expect(result).to eq(workflow_execution_double)

      expect(workflow_executor.execution).to eq(workflow_execution_double)
    end

    context 'when workflow has no batching configuration' do
      let(:rows_relation) { double('ActiveRecord::Relation') }
      let(:batch_processor_double) { instance_double(BatchProcessor, call: true) }
      let(:batch_double) { instance_double(Batch, id: 123) }
      let(:workflow_execution_double) { instance_double(WorkflowExecution) }

      before do
        # Workflow config without liquid_templates or with empty liquid_templates
        allow(workflow).to receive(:config).and_return({ 'liquid_templates' => {} })
        allow(data_source).to receive(:rows).and_return(rows_relation)
        allow(Batch).to receive(:create!).and_return(batch_double)
        allow(BatchProcessor).to receive(:new).with(batch: batch_double,
                                                    workflow: workflow).and_return(batch_processor_double)
        allow(WorkflowExecution).to receive(:find_or_create_by).and_return(workflow_execution_double)
        allow(workflow_execution_double).to receive(:start!)
      end

      it 'processes all rows in a single batch' do
        expect(rows_relation).to receive(:update_all).with(batch_id: batch_double.id)

        workflow_executor.call

        expect(batch_processor_double).to have_received(:call)
        expect(Batch).to have_received(:create!)
      end
    end

    context 'when workflow has batching configuration' do
      let(:workflow_config) do
        {
          'liquid_templates' => {
            'group_by' => '{{row.reference}}',
            'sort_by' => '{{row.priority}}'
          }
        }
      end
      let(:row1) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '1' }) }
      let(:row2) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '2' }) }
      let(:row3) { instance_double(Row, data: { 'reference' => 'group_b', 'priority' => '1' }) }
      let(:rows) { [row1, row2, row3] }
      let(:batch_a) { instance_double(Batch, id: 1) }
      let(:batch_b) { instance_double(Batch, id: 2) }
      let(:batch_processor_a) { instance_double(BatchProcessor, call: true) }
      let(:batch_processor_b) { instance_double(BatchProcessor, call: true) }
      let(:workflow_execution_double) { instance_double(WorkflowExecution) }

      before do
        allow(workflow).to receive(:config).and_return(workflow_config)
        allow(data_source).to receive(:rows).and_return(rows)
        allow(Batch).to receive(:create!).and_return(batch_a, batch_b)
        allow(BatchProcessor).to receive(:new).with(batch: batch_a, workflow: workflow).and_return(batch_processor_a)
        allow(BatchProcessor).to receive(:new).with(batch: batch_b, workflow: workflow).and_return(batch_processor_b)
        allow(WorkflowExecution).to receive(:find_or_create_by).and_return(workflow_execution_double)
        allow(workflow_execution_double).to receive(:start!)
      end

      xit 'groups rows by group_by template and creates separate batches' do
        # Mock row updates for each batch
        expect(row1).to receive(:update!).with(batch_id: batch_a.id)
        expect(row2).to receive(:update!).with(batch_id: batch_a.id)
        expect(row3).to receive(:update!).with(batch_id: batch_b.id)

        workflow_executor.call

        # Verify that both batch processors were called
        expect(batch_processor_a).to have_received(:call)
        expect(batch_processor_b).to have_received(:call)
        # Verify that two batches were created
        expect(Batch).to have_received(:create!).twice
      end
    end
  end
end

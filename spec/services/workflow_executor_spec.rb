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
  end
end

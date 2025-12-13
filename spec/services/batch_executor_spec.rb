# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchExecutor do
  let(:workflow) { create(:workflow) }
  let(:data_source) { create(:data_source) }
  let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: data_source) }
  let(:batch) { create(:batch, workflow_execution: workflow_execution) }

  before do
    create(:step, workflow: workflow, order: 1, config: {
             'liquid_templates' => {
               'name' => 'Test Step',
               'url' => 'https://api.example.com/test',
               'method' => 'get'
             }
           })

    # Stub HydraManager to prevent HTTP and immediately invoke callbacks
    allow(HydraManager.instance).to receive(:queue) do |**args|
      response = double('Response', code: 200, body: '{"id": "123"}')
      args[:on_complete]&.call(response)
    end
    allow(HydraManager.instance).to receive(:run)
  end

  describe "#initialize" do
    it "creates a new instance with required attributes" do
      executor = described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution)

      expect(executor.batch).to eq(batch)
      expect(executor.workflow).to eq(workflow)
      expect(executor.workflow_execution).to eq(workflow_execution)
    end

    it "creates a BatchExecution" do
      executor = described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution)

      expect(executor.execution).to be_a(BatchExecution)
      expect(executor.execution.batch).to eq(batch)
      expect(executor.execution.workflow).to eq(workflow)
    end

    it "raises ArgumentError when batch is nil" do
      expect { described_class.new(batch: nil, workflow: workflow, workflow_execution: workflow_execution) }
        .to raise_error(ArgumentError, "batch is required")
    end

    it "raises ArgumentError when workflow is nil" do
      expect { described_class.new(batch: batch, workflow: nil, workflow_execution: workflow_execution) }
        .to raise_error(ArgumentError, "workflow is required")
    end

    it "raises ArgumentError when workflow_execution is nil" do
      expect { described_class.new(batch: batch, workflow: workflow, workflow_execution: nil) }
        .to raise_error(ArgumentError, "workflow_execution is required")
    end
  end

  describe "#call" do
    context "with rows in the batch" do
      before do
        create_list(:row, 3, batch: batch, data_source: data_source)
      end

      it "creates RowExecutions for each row" do
        described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution).call

        expect(RowExecution.count).to eq(3)
        expect(RowExecution.pluck(:status).uniq).to eq(['complete'])
      end

      it "starts and completes the batch execution" do
        executor = described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution)
        executor.call

        expect(executor.execution.status).to eq('complete')
        expect(executor.execution.started_at).to be_present
        expect(executor.execution.completed_at).to be_present
      end
    end

    context "sequential processing mode" do
      before do
        batch.update!(processing_mode: 'sequential')
        create_list(:row, 3, batch: batch, data_source: data_source)
      end

      it "calls HydraManager.run once per row" do
        run_count = 0
        allow(HydraManager.instance).to receive(:run) { run_count += 1 }

        described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution).call

        expect(run_count).to eq(3)
      end
    end

    context "parallel processing mode" do
      before do
        batch.update!(processing_mode: 'parallel')
        create_list(:row, 3, batch: batch, data_source: data_source)
      end

      it "calls HydraManager.run once for all rows" do
        run_count = 0
        allow(HydraManager.instance).to receive(:run) { run_count += 1 }

        described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution).call

        expect(run_count).to eq(1)
      end
    end

    context "with no rows" do
      it "completes without creating any RowExecutions" do
        executor = described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution)
        executor.call

        expect(RowExecution.count).to eq(0)
        expect(executor.execution.status).to eq('complete')
      end
    end
  end

  describe "#check_completion" do
    it "delegates to the batch execution" do
      executor = described_class.new(batch: batch, workflow: workflow, workflow_execution: workflow_execution)

      expect(executor.execution).to receive(:check_completion).and_return(true)
      expect(executor.check_completion).to eq(true)
    end
  end
end

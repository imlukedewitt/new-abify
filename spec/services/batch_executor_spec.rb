# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchExecutor do
  subject(:processor) { described_class.new(batch: batch_object, workflow: workflow, workflow_execution: workflow_execution) }

  let(:batch_object) { build(:batch) }
  let(:workflow) { build(:workflow) }
  let(:workflow_execution) { build(:workflow_execution, workflow: workflow) }

  describe "#initialize" do
    it "creates a new instance with a batch, workflow, and workflow_execution" do
      processor = described_class.new(batch: batch_object, workflow: workflow, workflow_execution: workflow_execution)
      expect(processor).to be_a(BatchExecutor)
    end

    it "stores the batch, workflow, and workflow_execution as attributes" do
      processor = described_class.new(batch: batch_object, workflow: workflow, workflow_execution: workflow_execution)
      expect(processor.batch).to eq(batch_object)
      expect(processor.workflow).to eq(workflow)
      expect(processor.workflow_execution).to eq(workflow_execution)
    end

    it "creates a new batch execution" do
      expect(processor.execution).to be_a(BatchExecution)
      expect(processor.execution.batch).to eq(batch_object)
      expect(processor.execution.workflow).to eq(workflow)
    end

    context "when batch is nil" do
      let(:batch_object) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch_object, workflow: workflow, workflow_execution: workflow_execution) }
          .to raise_error(ArgumentError, "batch is required")
      end
    end

    context "when workflow is nil" do
      let(:workflow) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch_object, workflow: workflow, workflow_execution: workflow_execution) }
          .to raise_error(ArgumentError, "workflow is required")
      end
    end

    context "when workflow_execution is nil" do
      let(:workflow_execution) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch_object, workflow: workflow, workflow_execution: workflow_execution) }
          .to raise_error(ArgumentError, "workflow_execution is required")
      end
    end
  end

  describe "#call" do
    let(:rows) { build_list(:row, 3) }

    before do
      allow(batch_object).to receive(:rows).and_return(rows)
    end

    it "processes rows sequentially and waits for completion" do
      allow(processor.execution).to receive(:complete?).and_return(true)

      row_processor_doubles = rows.map do
        instance_double(RowExecutor)
      end

      expect(processor.execution).to receive(:start!).ordered

      rows.each_with_index do |row, index|
        row_processor_double = row_processor_doubles[index]

        expect(RowExecutor).to receive(:new)
          .with(row: row, workflow: workflow, workflow_execution: workflow_execution)
          .and_return(row_processor_double)
          .ordered
        expect(row_processor_double).to receive(:call).ordered
        expect(HydraManager.instance).to receive(:run).ordered # Called per row
        expect(row_processor_double).to receive(:wait_for_completion).ordered
      end

      expect(processor.execution).to receive(:check_completion).ordered

      processor.call
    end

    it "processes rows in parallel and runs hydra only once" do
      allow(processor.execution).to receive(:complete?).and_return(true)
      allow(batch_object).to receive(:processing_mode).and_return("parallel")

      row_processor_doubles = rows.map { instance_double(RowExecutor) }

      rows.each_with_index do |row, index|
        row_processor_double = row_processor_doubles[index]
        expect(RowExecutor).to receive(:new)
          .with(row: row, workflow: workflow, workflow_execution: workflow_execution)
          .and_return(row_processor_double)
        expect(row_processor_double).to receive(:call)
        expect(row_processor_double).to receive(:wait_for_completion)
      end

      expect(HydraManager.instance).to receive(:run).once

      expect(processor.execution).to receive(:start!).once
      expect(processor.execution).to receive(:check_completion).once

      processor.call
    end
  end

  describe "#check_completion" do
    it "delegates to the batch execution" do
      expect(processor.execution).to receive(:check_completion).and_return(true)

      expect(processor.check_completion).to eq(true)
    end
  end
end

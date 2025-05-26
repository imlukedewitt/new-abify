# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchProcessor do
  let(:batch_object) { build(:batch) }
  let(:workflow) { build(:workflow) }

  describe "#initialize" do
    it "creates a new instance with a batch and workflow" do
      processor = described_class.new(batch: batch_object, workflow: workflow)
      expect(processor).to be_a(BatchProcessor)
    end

    it "stores the batch and workflow as attributes" do
      processor = described_class.new(batch: batch_object, workflow: workflow)
      expect(processor.batch).to eq(batch_object)
      expect(processor.workflow).to eq(workflow)
    end

    context "when batch is nil" do
      let(:batch_object) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch_object, workflow: workflow) }
          .to raise_error(ArgumentError, "batch is required")
      end
    end

    context "when workflow is nil" do
      let(:workflow) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch_object, workflow: workflow) }
          .to raise_error(ArgumentError, "workflow is required")
      end
    end

    context "when the workflow does not have steps" do
      let(:workflow) { build(:workflow, steps: []) }

      xit "raises an ArgumentError" do
        expect { described_class.new(batch: batch_object, workflow: workflow) }
          .to raise_error(ArgumentError, "workflow must contain at least one step")
      end
    end
  end

  describe "#call" do
    let(:rows) { build_list(:row, 3) }

    before do
      allow(batch_object).to receive(:rows).and_return(rows)

      rows.each do |row|
        row_processor_instance_double = instance_double(RowProcessor)
        expect(RowProcessor).to receive(:new)
          .with(row: row, workflow: workflow)
          .and_return(row_processor_instance_double)
        expect(row_processor_instance_double).to receive(:call)
      end
    end

    it "creates a RowProcessor for each row and calls it" do
      processor = described_class.new(batch: batch_object, workflow: workflow)
      processor.call
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe RowProcessor do
  subject(:processor) { described_class.new(row: row, workflow: workflow) }

  let(:row) { build(:row) }
  let(:workflow) { build(:workflow) }

  describe "#initialize" do
    it "creates a new instance with a row and workflow" do
      expect(processor).to be_a(RowProcessor)
    end

    context "when row is nil" do
      let(:row) { nil }

      it "raises an ArgumentError" do
        expect { processor }.to raise_error(ArgumentError, "row is required")
      end
    end

    context "when workflow is nil" do
      let(:workflow) { nil }

      it "raises an ArgumentError" do
        expect { processor }.to raise_error(ArgumentError, "workflow is required")
      end
    end

    context "when arguments are missing" do
      it "raises an ArgumentError for missing row" do
        expect do
          described_class.new(workflow: workflow)
        end.to raise_error(ArgumentError)
      end

      it "raises an ArgumentError for missing workflow" do
        expect do
          described_class.new(row: row)
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe "#call" do
    let(:first_step) { build(:step, order: 1) }
    let(:second_step) { build(:step, order: 2) }

    before do
      allow(workflow).to receive(:steps).and_return([second_step, first_step])
    end

    it "responds to call" do
      expect(processor).to respond_to(:call)
    end

    it "processes steps in order starting with lowest order number" do
      step_processor = instance_double(StepProcessor)
      expect(StepProcessor).to receive(:new)
        .with(first_step, row, anything)
        .and_return(step_processor)
      expect(step_processor).to receive(:call)

      processor.call
    end
  end
end

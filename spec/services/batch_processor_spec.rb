# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchProcessor do
  let(:batch) { build(:batch) }
  let(:workflow) { build(:workflow) }

  describe "#initialize" do
    it "creates a new instance with a batch and workflow" do
      processor = described_class.new(batch: batch, workflow: workflow)
      expect(processor).to be_a(BatchProcessor)
    end

    context "when batch is nil" do
      let(:batch) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch, workflow: workflow) }
          .to raise_error(ArgumentError, "batch is required")
      end
    end

    context "when workflow is nil" do
      let(:workflow) { nil }

      it "raises an ArgumentError" do
        expect { described_class.new(batch: batch, workflow: workflow) }
          .to raise_error(ArgumentError, "workflow is required")
      end
    end
  end
end

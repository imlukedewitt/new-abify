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
  end
end

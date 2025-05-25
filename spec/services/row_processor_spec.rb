# frozen_string_literal: true

require "rails_helper"

RSpec.describe RowProcessor do
  subject(:processor) { described_class.new(row: row, workflow: workflow) }

  let(:row) { build(:row) }
  let(:workflow) { build(:workflow) }

  describe "#call" do
    it "initializes with a row and workflow" do
      expect(processor).to be_a(RowProcessor)
    end
  end
end
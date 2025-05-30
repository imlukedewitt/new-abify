require 'rails_helper'

RSpec.describe BatchExecution, type: :model do
  describe 'validations and associations' do
    it "belongs to a batch" do
      association = BatchExecution.reflect_on_association(:batch)
      expect(association.macro).to eq :belongs_to
    end

    it "belongs to a workflow" do
      association = BatchExecution.reflect_on_association(:workflow)
      expect(association.macro).to eq :belongs_to
    end

    it "has many row_executions through batch" do
      association = BatchExecution.reflect_on_association(:row_executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:through]).to eq :batch
    end
  end

  describe "#all_rows_complete?" do
    let(:batch) { create(:batch) }
    let(:workflow) { create(:workflow) }
    let(:batch_execution) { create(:batch_execution, batch: batch, workflow: workflow, status: Executable::PROCESSING) }

    context "when there are no row executions" do
      it "returns true" do
        expect(batch_execution.all_rows_complete?).to be true
      end
    end

    context "when all row executions are complete" do
      before do
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SUCCESS)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::FAILED)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SKIPPED)
      end

      it "returns true" do
        expect(batch_execution.all_rows_complete?).to be true
      end
    end

    context "when some row executions are still pending or processing" do
      before do
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SUCCESS)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::PENDING)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::PROCESSING)
      end

      it "returns false" do
        expect(batch_execution.all_rows_complete?).to be false
      end
    end
  end

  describe "#check_completion" do
    let(:batch) { create(:batch) }
    let(:workflow) { create(:workflow) }
    let(:batch_execution) { create(:batch_execution, batch: batch, workflow: workflow, status: Executable::PROCESSING) }

    context "when the execution is not in processing state" do
      before do
        batch_execution.update(status: Executable::PENDING)
      end

      it "returns nil without updating the status" do
        expect(batch_execution.check_completion).to be_nil
        expect(batch_execution.status).to eq(Executable::PENDING)
      end
    end

    context "when not all rows are complete" do
      before do
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SUCCESS)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::PROCESSING)
      end

      it "returns false without updating the status" do
        expect(batch_execution.check_completion).to be false
        expect(batch_execution.status).to eq(Executable::PROCESSING)
      end
    end

    context "when all rows are complete and none have failed" do
      before do
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SUCCESS)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SUCCESS)
      end

      it "updates status to complete and returns true" do
        expect(batch_execution).to receive(:complete!)
        expect(batch_execution.check_completion).to be true
      end
    end

    context "when all rows are complete and some have failed" do
      before do
        create(:row_execution, row: create(:row, batch: batch), status: Executable::SUCCESS)
        create(:row_execution, row: create(:row, batch: batch), status: Executable::FAILED)
      end

      it "updates status to failed and returns true" do
        expect(batch_execution).to receive(:fail!).with("Some rows failed processing")
        expect(batch_execution.check_completion).to be true
      end
    end
  end
end

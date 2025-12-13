# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RowExecution, type: :model do
  describe 'associations' do
    it 'belongs to a row' do
      association = described_class.reflect_on_association(:row)
      expect(association.macro).to eq :belongs_to
    end

    it 'belongs to a workflow_execution' do
      association = described_class.reflect_on_association(:workflow_execution)
      expect(association.macro).to eq :belongs_to
    end

    it 'has many step_executions' do
      association = described_class.reflect_on_association(:step_executions)
      expect(association.macro).to eq :has_many
    end
  end

  describe 'validations' do
    let(:row_execution) { build(:row_execution) }

    it 'validates presence of status' do
      row_execution.status = nil
      expect(row_execution).not_to be_valid
      expect(row_execution.errors[:status]).to include("can't be blank")
    end

    it 'allows valid statuses' do
      valid_statuses = %w[pending processing complete failed]
      valid_statuses.each do |status|
        row_execution.status = status
        expect(row_execution).to be_valid
      end
    end

    it 'rejects invalid statuses' do
      row_execution.status = 'invalid_status'
      expect(row_execution).not_to be_valid
      expect(row_execution.errors[:status]).to include('is not included in the list')
    end
  end

  describe 'status transitions' do
    let(:row_execution) { create(:row_execution) }

    describe '#start!' do
      it 'changes status to processing and sets started_at' do
        expect do
          row_execution.start!
        end.to change(row_execution, :status).from('pending').to('processing')
                                             .and change(row_execution, :started_at).from(nil)
      end
    end

    describe '#complete!' do
      before { row_execution.start! }

      it 'changes status to complete and sets completed_at' do
        expect do
          row_execution.complete!
        end.to change(row_execution, :status).from('processing').to('complete')
                                             .and change(row_execution, :completed_at).from(nil)
      end
    end

    describe '#fail!' do
      before { row_execution.start! }

      it 'changes status to failed and sets completed_at' do
        expect do
          row_execution.fail!
        end.to change(row_execution, :status).from('processing').to('failed')
                                             .and change(row_execution, :completed_at).from(nil)
      end
    end
  end

  describe 'status checks' do
    it '#complete? returns true when status is complete' do
      execution = build(:row_execution, status: 'complete')
      expect(execution.complete?).to be true
    end

    it '#failed? returns true when status is failed' do
      execution = build(:row_execution, status: 'failed')
      expect(execution.failed?).to be true
    end

    it '#pending? returns true when status is pending' do
      execution = build(:row_execution, status: 'pending')
      expect(execution.pending?).to be true
    end

    it '#processing? returns true when status is processing' do
      execution = build(:row_execution, status: 'processing')
      expect(execution.processing?).to be true
    end
  end

  describe '#step_statuses' do
    let(:row) { create(:row) }
    let(:row_execution) { create(:row_execution, row: row) }
    let(:workflow) { create(:workflow) }
    let(:step1) { create(:step, workflow: workflow, order: 1) }
    let(:step2) { create(:step, workflow: workflow, order: 2) }
    let(:step3) { create(:step, workflow: workflow, order: 3) }

    before do
      create(:step_execution, step: step1, row: row, row_execution: row_execution, status: 'success')
      create(:step_execution, step: step2, row: row, row_execution: row_execution, status: 'failed')
      create(:step_execution, step: step3, row: row, row_execution: row_execution, status: 'pending')
    end

    it 'returns counts of step statuses' do
      expect(row_execution.step_statuses).to include(
        'success' => 1,
        'failed' => 1,
        'pending' => 1,
        'processing' => 0,
        'skipped' => 0,
        'total' => 3
      )
    end
  end

  describe '#merged_success_data' do
    let(:row) { create(:row) }
    let(:row_execution) { create(:row_execution, row: row) }
    let(:workflow) { create(:workflow) }
    let(:step1) { create(:step, workflow: workflow, order: 1) }
    let(:step2) { create(:step, workflow: workflow, order: 2) }
    let(:step3) { create(:step, workflow: workflow, order: 3) }

    it 'returns empty hash when no step executions exist' do
      expect(row_execution.merged_success_data).to eq({})
    end

    it 'merges success data from completed steps in order' do
      create(:step_execution, step: step1, row: row, row_execution: row_execution,
                              status: 'success', result: { 'data' => { 'customer_id' => '123' } })
      create(:step_execution, step: step2, row: row, row_execution: row_execution,
                              status: 'success', result: { 'data' => { 'subscription_id' => '456' } })

      expect(row_execution.merged_success_data).to eq({
                                                        'customer_id' => '123',
                                                        'subscription_id' => '456'
                                                      })
    end

    it 'excludes non-success step executions' do
      create(:step_execution, step: step1, row: row, row_execution: row_execution,
                              status: 'success', result: { 'data' => { 'customer_id' => '123' } })
      create(:step_execution, step: step2, row: row, row_execution: row_execution,
                              status: 'failed', result: { 'data' => { 'should_not_appear' => 'true' } })
      create(:step_execution, step: step3, row: row, row_execution: row_execution,
                              status: 'pending', result: nil)

      expect(row_execution.merged_success_data).to eq({ 'customer_id' => '123' })
    end

    it 'later steps overwrite earlier step data with same keys' do
      create(:step_execution, step: step1, row: row, row_execution: row_execution,
                              status: 'success', result: { 'data' => { 'status' => 'pending' } })
      create(:step_execution, step: step2, row: row, row_execution: row_execution,
                              status: 'success', result: { 'data' => { 'status' => 'active' } })

      expect(row_execution.merged_success_data).to eq({ 'status' => 'active' })
    end

    it 'handles nil result data gracefully' do
      create(:step_execution, step: step1, row: row, row_execution: row_execution,
                              status: 'success', result: nil)

      expect(row_execution.merged_success_data).to eq({})
    end

    it 'handles empty data hash gracefully' do
      create(:step_execution, step: step1, row: row, row_execution: row_execution,
                              status: 'success', result: { 'data' => {} })

      expect(row_execution.merged_success_data).to eq({})
    end
  end
end

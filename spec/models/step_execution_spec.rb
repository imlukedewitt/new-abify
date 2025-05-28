# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepExecution, type: :model do
  describe 'associations' do
    it 'belongs to a step' do
      association = described_class.reflect_on_association(:step)
      expect(association.macro).to eq :belongs_to
    end

    it 'belongs to a row' do
      association = described_class.reflect_on_association(:row)
      expect(association.macro).to eq :belongs_to
    end
  end

  describe 'validations' do
    let(:step_execution) { build(:step_execution) }

    it 'validates presence of status' do
      step_execution.status = nil
      expect(step_execution).not_to be_valid
      expect(step_execution.errors[:status]).to include("can't be blank")
    end

    it 'allows valid statuses' do
      valid_statuses = %w[pending processing success failed skipped]
      valid_statuses.each do |status|
        step_execution.status = status
        expect(step_execution).to be_valid
      end
    end

    it 'rejects invalid statuses' do
      step_execution.status = 'invalid_status'
      expect(step_execution).not_to be_valid
      expect(step_execution.errors[:status]).to include('is not included in the list')
    end
  end

  describe 'state management' do
    let(:step_execution) { create(:step_execution) }

    describe '#start!' do
      it 'changes status to processing and sets started_at' do
        expect do
          step_execution.start!
        end.to change(step_execution, :status).from('pending').to('processing')
                                              .and change(step_execution, :started_at).from(nil)
      end
    end

    describe '#succeed!' do
      before { step_execution.start! }

      it 'changes status to success and sets completed_at' do
        expect do
          step_execution.succeed!(customer_id: '123')
        end.to change(step_execution, :status).from('processing').to('success')
                                              .and change(step_execution, :completed_at).from(nil)
      end

      it 'stores result data' do
        step_execution.succeed!(customer_id: '123')
        expect(step_execution.reload.result).to eq({
                                                     'success' => true,
                                                     'data' => { 'customer_id' => '123' }
                                                   })
      end
    end

    describe '#fail!' do
      before { step_execution.start! }

      it 'changes status to failed and sets completed_at' do
        expect do
          step_execution.fail!('API Error')
        end.to change(step_execution, :status).from('processing').to('failed')
                                              .and change(step_execution, :completed_at).from(nil)
      end

      it 'stores error information as array' do
        step_execution.fail!('API Error')
        expect(step_execution.reload.result).to eq({
                                                     'success' => false,
                                                     'errors' => ['API Error']
                                                   })
      end

      it 'handles array of errors' do
        step_execution.fail!(['API Error', 'Connection timeout'])
        expect(step_execution.reload.result).to eq({
                                                     'success' => false,
                                                     'errors' => ['API Error', 'Connection timeout']
                                                   })
      end
    end

    describe '#skip!' do
      it 'changes status to skipped and sets completed_at' do
        expect do
          step_execution.skip!
        end.to change(step_execution, :status).from('pending').to('skipped')
                                              .and change(step_execution, :completed_at).from(nil)
      end

      it 'stores result with skipped flag' do
        step_execution.skip!
        expect(step_execution.reload.result).to eq({
                                                     'success' => true,
                                                     'skipped' => true
                                                   })
      end
    end
  end

  describe 'status checks' do
    it '#success? returns true when status is success' do
      execution = build(:step_execution, status: 'success')
      expect(execution.success?).to be true
    end

    it '#failed? returns true when status is failed' do
      execution = build(:step_execution, status: 'failed')
      expect(execution.failed?).to be true
    end

    it '#skipped? returns true when status is skipped' do
      execution = build(:step_execution, status: 'skipped')
      expect(execution.skipped?).to be true
    end

    it '#pending? returns true when status is pending' do
      execution = build(:step_execution, status: 'pending')
      expect(execution.pending?).to be true
    end

    it '#processing? returns true when status is processing' do
      execution = build(:step_execution, status: 'processing')
      expect(execution.processing?).to be true
    end

    describe '#complete?' do
      it 'returns true when successful' do
        execution = build(:step_execution, status: 'success')
        expect(execution.complete?).to be true
      end

      it 'returns true when failed' do
        execution = build(:step_execution, status: 'failed')
        expect(execution.complete?).to be true
      end

      it 'returns true when skipped' do
        execution = build(:step_execution, status: 'skipped')
        expect(execution.complete?).to be true
      end

      it 'returns false when pending' do
        execution = build(:step_execution, status: 'pending')
        expect(execution.complete?).to be false
      end

      it 'returns false when processing' do
        execution = build(:step_execution, status: 'processing')
        expect(execution.complete?).to be false
      end
    end
  end
end

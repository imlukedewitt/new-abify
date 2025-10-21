# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepExecutor, type: :service do
  describe 'with StepExecution integration' do
    let(:step) { create(:step) }
    let(:row) { create(:row) }
    let(:hydra_manager) { instance_double(HydraManager) }
    let(:step_execution) { create(:step_execution, step: step, row: row) }
    let(:callback) { ->(result) {} }
    let(:processor) { described_class.new(step, row, on_complete: callback, hydra_manager: hydra_manager) }

    before do
      allow(StepExecution).to receive(:find_or_create_by).and_return(step_execution)
      allow(hydra_manager).to receive(:queue).and_return(double('Typhoeus::Request'))
    end

    it 'creates or finds a StepExecution record' do
      expect(StepExecution).to receive(:find_or_create_by).with(step: step, row: row).and_return(step_execution)
      processor.call
    end

    it 'starts the StepExecution when calling the processor' do
      expect(step_execution).to receive(:start!)
      processor.call
    end

    context 'when processing response' do
      let(:success_response) do
        double('response', body: '{"customer":{"id":"123"}}', code: 200)
      end

      let(:failure_response) do
        double('response', body: '{"errors":["Not found"]}', code: 404)
      end

      it 'marks execution as successful when API returns success' do
        expect(step_execution).to receive(:succeed!).with(hash_including('customer_id' => '123'))

        expect(hydra_manager).to receive(:queue) do |args|
          args[:on_complete].call(success_response)
        end

        processor.call
      end

      it 'marks execution as failed when API returns error' do
        expect(step_execution).to receive(:fail!).with(["Not found"])

        expect(hydra_manager).to receive(:queue) do |args|
          args[:on_complete].call(failure_response)
        end

        processor.call
      end
    end

    context 'when skipping steps' do
      before do
        allow(processor).to receive(:should_skip?).and_return(true)
      end

      it 'marks execution as skipped without calling API' do
        expect(step_execution).to receive(:skip!)
        expect(hydra_manager).not_to receive(:queue)

        processor.call
      end
    end
  end
end

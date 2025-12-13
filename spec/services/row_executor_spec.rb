# frozen_string_literal: true

require "rails_helper"

RSpec.describe RowExecutor do
  subject(:processor) { described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution) }

  let(:row) { build(:row) }
  let(:workflow) { build(:workflow) }
  let(:workflow_execution) { build(:workflow_execution, workflow: workflow) }

  describe "#initialize" do
    it "creates a new instance with a row and workflow" do
      expect(processor).to be_a(RowExecutor)
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

    describe "#wait_for_completion" do
      let(:execution_double) { instance_double(RowExecution) }

      before do
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
      end

      it "blocks until the row processing is complete" do
        allow(workflow).to receive(:steps).and_return([])
        allow(execution_double).to receive(:complete!)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        # Track completion order
        completion_order = []

        # Create processor and start processing in a separate thread
        completion_thread = Thread.new do
          processor.call
          completion_order << :processing_done
        end

        # Start waiting for completion in another thread
        wait_thread = Thread.new do
          processor.wait_for_completion
          completion_order << :wait_done
        end

        # Wait for both threads to complete
        completion_thread.join
        wait_thread.join

        # Verify that processing completed before wait returned
        expect(completion_order).to eq(%i[processing_done wait_done])
      end

      it "returns immediately if already completed" do
        allow(workflow).to receive(:steps).and_return([])
        allow(execution_double).to receive(:complete!)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        # Complete the processing first
        processor.call

        # wait_for_completion should return immediately
        start_time = Time.current
        processor.wait_for_completion
        end_time = Time.current

        expect(end_time - start_time).to be < 0.1
      end

      it "handles completion when execution is already complete" do
        allow(execution_double).to receive(:complete?).and_return(true)
        allow(execution_double).to receive(:failed?).and_return(false)

        # Should mark as completed and return immediately
        start_time = Time.current
        processor.call
        processor.wait_for_completion
        end_time = Time.current

        expect(end_time - start_time).to be < 0.1
      end
    end
  end

  describe "#call" do
    let(:first_step) { build(:step, order: 1) }
    let(:second_step) { build(:step, order: 2) }

    before do
      allow(workflow).to receive(:steps).and_return([second_step, first_step])
    end

    it "does not process next steps if a required step fails" do
      required_step = build(:step, order: 1, name: "Required Step")
      next_step = build(:step, order: 2)

      allow(workflow).to receive(:steps).and_return([required_step, next_step])

      required_processor = instance_double(StepExecutor)

      allow(StepExecutor).to receive(:new)
        .with(required_step, row, anything)
        .and_return(required_processor)

      allow(required_processor).to receive(:should_skip?).and_return(false)
      allow(required_processor).to receive(:required?).and_return(true)
      allow(required_processor).to receive(:call) do
        processor.send(:handle_step_completion, { success: false, error: "Failure in required step" })
      end

      execution_double = instance_double(RowExecution)
      allow(RowExecution).to receive(:new).with(row: row).and_return(execution_double)
      allow(execution_double).to receive(:start!)
      allow(execution_double).to receive(:processing?).and_return(false)
      allow(execution_double).to receive(:complete?)

      allow(row).to receive(:update).with(status: :failed)

      expect(StepExecutor).not_to receive(:new).with(next_step, row, anything)
    end

    it "processes steps in sequence and completes" do
      first_processor = instance_double(StepExecutor)
      second_processor = instance_double(StepExecutor)

      expect(StepExecutor).to receive(:new)
        .with(first_step, row, anything)
        .and_return(first_processor)
      allow(first_processor).to receive(:should_skip?).and_return(false)
      expect(first_processor).to receive(:call)

      processor.call

      expect(StepExecutor).to receive(:new)
        .with(second_step, row, anything)
        .and_return(second_processor)
      allow(second_processor).to receive(:should_skip?).and_return(false)
      expect(second_processor).to receive(:call)

      # Simulate completion of first step with success
      processor.send(:handle_step_completion, { success: true, data: { 'customer_id' => '123' } })

      expect(StepExecutor).not_to receive(:new)
      processor.send(:handle_step_completion, { success: true, data: { 'subscription_id' => '456' } })
    end

    it "skips steps when should_skip? returns true" do
      first_processor = instance_double(StepExecutor)
      second_processor = instance_double(StepExecutor)

      expect(StepExecutor).to receive(:new)
        .with(first_step, row, anything)
        .and_return(first_processor)
      allow(first_processor).to receive(:should_skip?).and_return(true)
      expect(first_processor).not_to receive(:call)

      expect(StepExecutor).to receive(:new)
        .with(second_step, row, anything)
        .and_return(second_processor)
      allow(second_processor).to receive(:should_skip?).and_return(false)
      expect(second_processor).to receive(:call)

      processor.call
    end

    it "handles steps without success_data" do
      step_without_data = build(:step, order: 1, config: {
                                  'liquid_templates' => {
                                    'method' => 'get',
                                    'url' => 'https://api.example.com/endpoint'
                                  }
                                })
      allow(workflow).to receive(:steps).and_return([step_without_data])

      test_processor = described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution)
      step_processor = instance_double(StepExecutor)

      expect(StepExecutor).to receive(:new)
        .with(step_without_data, row, anything)
        .and_return(step_processor)
      allow(step_processor).to receive(:should_skip?).and_return(false)
      expect(step_processor).to receive(:call)

      test_processor.call

      expect do
        test_processor.send(:handle_step_completion, { success: true, data: {} })
      end.not_to raise_error
    end

    context "with @in_progress and priority logic" do
      let(:hydra_manager_double) { instance_double(HydraManager) }
      let(:on_complete_method) { processor.method(:handle_step_completion) } # Memoized for consistent object in mocks

      before do
        allow(HydraManager).to receive(:instance).and_return(hydra_manager_double)
      end

      it "initializes the first StepExecutor with priority: false and starts execution" do
        allow(workflow).to receive(:steps).and_return([first_step])
        step_processor_double = instance_double(StepExecutor, should_skip?: false)
        allow(step_processor_double).to receive(:call)

        execution_double = instance_double(RowExecution, processing?: false)
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
        allow(execution_double).to receive(:start!)
        allow(execution_double).to receive(:complete?)

        expect(StepExecutor).to receive(:new).with(
          first_step,
          row,
          hash_including(
            priority: false,
            on_complete: on_complete_method,
            hydra_manager: hydra_manager_double
          )
        ).and_return(step_processor_double)

        processor.call
        expect(execution_double).to have_received(:start!)
      end

      it "initializes subsequent StepExecutors with priority: true" do
        allow(workflow).to receive(:steps).and_return([first_step, second_step])
        first_sp_double = instance_double(StepExecutor, should_skip?: false)
        allow(first_sp_double).to receive(:call)
        second_sp_double = instance_double(StepExecutor, should_skip?: false)
        allow(second_sp_double).to receive(:call)

        execution_double = instance_double(RowExecution)
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
        allow(execution_double).to receive(:start!)
        allow(execution_double).to receive(:processing?).and_return(false, true)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        expect(StepExecutor).to receive(:new).with(
          first_step, row, hash_including(priority: false, on_complete: on_complete_method)
        ).ordered.and_return(first_sp_double)

        expect(StepExecutor).to receive(:new).with(
          second_step, row, hash_including(priority: true, on_complete: on_complete_method)
        ).ordered.and_return(second_sp_double)

        processor.call
        processor.send(:handle_step_completion, { success: true, data: {} })
      end

      it "completes the execution when called with no steps" do
        allow(workflow).to receive(:steps).and_return([])

        execution_double = instance_double(RowExecution)
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
        allow(execution_double).to receive(:complete!)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        # Create processor after setting up the mocks
        row_processor = described_class.new(row: row, workflow: workflow, workflow_execution: workflow_execution)

        expect(StepExecutor).not_to receive(:new)
        row_processor.call
        expect(execution_double).to have_received(:complete!)
      end

      it "completes the execution after all steps are processed" do
        allow(workflow).to receive(:steps).and_return([first_step])
        step_processor_double = instance_double(StepExecutor, should_skip?: false)
        allow(step_processor_double).to receive(:call)

        execution_double = instance_double(RowExecution, processing?: false)
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
        allow(execution_double).to receive(:start!)
        allow(execution_double).to receive(:complete!)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        expect(StepExecutor).to receive(:new).with(
          first_step, row, hash_including(priority: false, on_complete: on_complete_method)
        ).and_return(step_processor_double)

        processor.call

        processor.send(:handle_step_completion, { success: true, data: {} })

        expect(processor.instance_variable_get(:@current_step_index)).to eq 1
        expect(execution_double).to have_received(:complete!)
      end

      it "uses priority: false for the next step if the first step is skipped" do
        allow(workflow).to receive(:steps).and_return([first_step, second_step])
        first_sp_double = instance_double(StepExecutor, should_skip?: true)
        second_sp_double = instance_double(StepExecutor, should_skip?: false)
        allow(second_sp_double).to receive(:call)

        execution_double = instance_double(RowExecution)
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
        allow(execution_double).to receive(:processing?).and_return(false)
        allow(execution_double).to receive(:start!)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        expect(StepExecutor).to receive(:new).with(
          first_step, row, hash_including(priority: false, on_complete: on_complete_method)
        ).ordered.and_return(first_sp_double)

        expect(StepExecutor).to receive(:new).with(
          second_step, row, hash_including(priority: false, on_complete: on_complete_method)
        ).ordered.and_return(second_sp_double)

        processor.call
      end

      it "uses priority: true for a step after a skipped step, if processing was already in progress" do
        third_step = build(:step, order: 3)
        allow(workflow).to receive(:steps).and_return([first_step, second_step, third_step])

        first_sp = instance_double(StepExecutor, should_skip?: false)
        allow(first_sp).to receive(:call)
        second_sp = instance_double(StepExecutor, should_skip?: true)
        third_sp = instance_double(StepExecutor, should_skip?: false)
        allow(third_sp).to receive(:call)

        execution_double = instance_double(RowExecution)
        allow(RowExecution).to receive(:new).with(row: row, workflow_execution: workflow_execution).and_return(execution_double)
        allow(execution_double).to receive(:start!)
        allow(execution_double).to receive(:processing?).and_return(false, true, true)
        allow(execution_double).to receive(:complete?)
        allow(execution_double).to receive(:failed?).and_return(false)

        expect(StepExecutor).to receive(:new).with(
          first_step, row, hash_including(priority: false, on_complete: on_complete_method)
        ).ordered.and_return(first_sp)

        expect(StepExecutor).to receive(:new).with(
          second_step, row, hash_including(priority: true, on_complete: on_complete_method)
        ).ordered.and_return(second_sp)

        expect(StepExecutor).to receive(:new).with(
          third_step, row, hash_including(priority: true, on_complete: on_complete_method)
        ).ordered.and_return(third_sp)

        processor.call
        processor.send(:handle_step_completion, { success: true, data: {} })
      end
    end
  end
end

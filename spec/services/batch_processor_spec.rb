# frozen_string_literal: true

require "rails_helper"

RSpec.describe BatchProcessor do
  subject(:processor) { described_class.new(batch: batch_object, workflow: workflow) }

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

    it "finds or creates a batch execution" do
      execution_double = instance_double(BatchExecution)
      expect(BatchExecution).to receive(:find_or_create_by)
        .with(batch: batch_object, workflow: workflow)
        .and_return(execution_double)

      expect(processor.execution).to eq(execution_double)
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
  end

  describe "#call" do
    let(:rows) { build_list(:row, 3) }

    before do
      allow(batch_object).to receive(:rows).and_return(rows)
    end

    it "processes rows sequentially and waits for completion" do
      execution_double = instance_double(BatchExecution)
      allow(BatchExecution).to receive(:find_or_create_by).and_return(execution_double)
      allow(execution_double).to receive(:complete?).and_return(true)

      row_processor_doubles = rows.map do
        instance_double(RowProcessor)
      end

      expect(execution_double).to receive(:start!).ordered

      rows.each_with_index do |row, index|
        row_processor_double = row_processor_doubles[index]

        expect(RowProcessor).to receive(:new)
          .with(row: row, workflow: workflow)
          .and_return(row_processor_double)
          .ordered
        expect(row_processor_double).to receive(:call).ordered
        expect(HydraManager.instance).to receive(:run).ordered # Called per row
        expect(row_processor_double).to receive(:wait_for_completion).ordered
      end

      expect(execution_double).to receive(:check_completion).ordered

      processor.call
    end
  end

  describe "#check_completion" do
    it "delegates to the batch execution" do
      execution_double = instance_double(BatchExecution)
      allow(BatchExecution).to receive(:find_or_create_by).and_return(execution_double)
      expect(execution_double).to receive(:check_completion).and_return(true)

      expect(processor.check_completion).to eq(true)
    end
  end

  describe "#start_monitor" do
    let(:execution_double) { instance_double(BatchExecution) }

    before do
      allow(BatchExecution).to receive(:find_or_create_by).and_return(execution_double)
      allow(execution_double).to receive(:complete?).and_return(false)
    end

    it "starts a monitoring thread" do
      # Allow the thread to exit immediately
      allow(Thread).to receive(:new).and_yield
      allow(processor).to receive(:check_completion).and_return(true)
      allow(Rails.logger).to receive(:info)

      processor.start_monitor

      expect(Rails.logger).to have_received(:info).with(/completed processing/)
    end

    it "doesn't start a new thread if one is already running" do
      thread_double = double("Thread", alive?: true)
      processor.instance_variable_set(:@monitor_thread, thread_double)

      expect(Thread).not_to receive(:new)

      processor.start_monitor
    end

    it "logs a warning if monitoring times out" do
      # Allow the thread to exit immediately after simulating timeout
      allow(Time).to receive(:current).and_return(Time.now, Time.now + 3601)
      allow(Thread).to receive(:new).and_yield
      allow(processor).to receive(:sleep)
      allow(Rails.logger).to receive(:warn)
      allow(execution_double).to receive(:complete?).and_return(false)

      processor.start_monitor

      expect(Rails.logger).to have_received(:warn).with(/monitor timed out/)
    end
  end

  describe "#stop_monitor" do
    it "stops the monitoring thread if running" do
      thread_double = double("Thread", alive?: true)
      expect(thread_double).to receive(:exit)
      processor.instance_variable_set(:@monitor_thread, thread_double)

      processor.stop_monitor

      expect(processor.monitor_thread).to be_nil
    end

    it "does nothing if no thread is running" do
      processor.instance_variable_set(:@monitor_thread, nil)

      expect { processor.stop_monitor }.not_to raise_error
    end
  end
end

# frozen_string_literal: true

# Processes a batch of rows with the given workflow
class BatchProcessor
  attr_reader :batch, :workflow, :execution

  def initialize(batch:, workflow:)
    raise ArgumentError, "batch is required" if batch.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?

    @batch = batch
    @workflow = workflow
    @execution = find_or_create_execution
    @monitor_thread = nil
  end

  def call
    @execution.start!

    if batch.processing_mode == "parallel"
      process_in_parallel
    else
      process_sequentially
    end

    check_completion
  end

  def check_completion
    @execution.check_completion
  end

  private

  def process_in_parallel
    row_processors = batch.rows.map do |row|
      row_processor = RowProcessor.new(row: row, workflow: workflow)
      row_processor.call
      row_processor
    end
    HydraManager.instance.run
    row_processors.each(&:wait_for_completion)
  end

  def process_sequentially
    batch.rows.each do |row|
      row_processor = RowProcessor.new(row: row, workflow: workflow)
      row_processor.call
      HydraManager.instance.run
      row_processor.wait_for_completion
    end
  end

  def find_or_create_execution
    BatchExecution.find_or_create_by(batch: batch, workflow: workflow)
  end
end

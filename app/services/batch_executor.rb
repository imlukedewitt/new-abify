# frozen_string_literal: true

# Executes a batch of rows with the given workflow
class BatchExecutor
  attr_reader :batch, :workflow, :execution

  def initialize(batch:, workflow:)
    raise ArgumentError, "batch is required" if batch.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?

    @batch = batch
    @workflow = workflow
    @execution = find_or_create_execution
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
    row_executors = batch.rows.map do |row|
      row_executor = RowExecutor.new(row: row, workflow: workflow)
      row_executor.call
      row_executor
    end
    HydraManager.instance.run
    row_executors.each(&:wait_for_completion)
  end

  def process_sequentially
    batch.rows.each do |row|
      row_executor = RowExecutor.new(row: row, workflow: workflow)
      row_executor.call
      HydraManager.instance.run
      row_executor.wait_for_completion
    end
  end

  def find_or_create_execution
    BatchExecution.find_or_create_by(batch: batch, workflow: workflow)
  end
end

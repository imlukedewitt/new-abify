# frozen_string_literal: true

# Executes a batch of rows with the given workflow
class BatchExecutor
  attr_reader :batch, :workflow, :workflow_execution, :execution

  def initialize(batch:, workflow:, workflow_execution:)
    raise ArgumentError, "batch is required" if batch.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?
    raise ArgumentError, "workflow_execution is required" if workflow_execution.nil?

    @batch = batch
    @workflow = workflow
    @workflow_execution = workflow_execution
    @execution = BatchExecution.new(batch: batch, workflow: workflow)
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
      row_executor = RowExecutor.new(row: row, workflow: workflow, workflow_execution: workflow_execution)
      row_executor.call
      row_executor
    end
    HydraManager.instance.run
    row_executors.each(&:wait_for_completion)
  end

  def process_sequentially
    batch.rows.each do |row|
      row_executor = RowExecutor.new(row: row, workflow: workflow, workflow_execution: workflow_execution)
      row_executor.call
      HydraManager.instance.run
      row_executor.wait_for_completion
    end
  end
end

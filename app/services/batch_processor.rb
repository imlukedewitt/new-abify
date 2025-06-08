# frozen_string_literal: true

# Processes a batch of rows with the given workflow
class BatchProcessor
  attr_reader :batch, :workflow, :execution, :monitor_thread

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

    batch.rows.each do |row|
      row_processor = RowProcessor.new(row: row, workflow: workflow)
      row_processor.call
      HydraManager.instance.run # TODO: should this live on the row processor?
      row_processor.wait_for_completion
    end

    check_completion

    start_monitor unless @execution.complete?
  end

  def check_completion
    @execution.check_completion
  end

  # TODO: remove this
  def start_monitor(interval: 5, max_runtime: 3600)
    return if @monitor_thread&.alive?

    @monitor_thread = Thread.new do
      start_time = Time.current

      while Time.current - start_time < max_runtime
        if check_completion
          Rails.logger.info "Batch #{batch.id} completed processing"
          break
        end

        sleep interval
      end

      Rails.logger.warn "Batch #{batch.id} monitor timed out after #{max_runtime} seconds" unless @execution.complete?
    end
  end

  # Stops the monitoring thread if running
  def stop_monitor
    return unless @monitor_thread&.alive?

    @monitor_thread.exit
    @monitor_thread = nil
  end

  private

  def find_or_create_execution
    BatchExecution.find_or_create_by(batch: batch, workflow: workflow)
  end
end

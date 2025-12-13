# frozen_string_literal: true

# Runs a Workflow on a single Row,
# creating StepExecutors for each step
class RowExecutor
  attr_reader :row, :workflow, :workflow_execution

  def initialize(row:, workflow:, workflow_execution:, step_templates: nil)
    raise ArgumentError, "row is required" if row.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?
    raise ArgumentError, "workflow_execution is required" if workflow_execution.nil?

    @row = row
    @workflow = workflow
    @workflow_execution = workflow_execution
    @step_templates = step_templates
    @ordered_steps = workflow.steps.sort_by(&:order)
    @current_step_index = 0
    @completion_semaphore = Thread::ConditionVariable.new
    @completion_mutex = Thread::Mutex.new
    @completed = false
  end

  def call
    if execution.complete?
      mark_completed
      return
    end

    # TODO: this is messy, need to clean up with logic in #handle_step_completion
    if @ordered_steps.empty? || @current_step_index >= @ordered_steps.length
      execution.complete!
      mark_completed
      return
    end

    process_current_step
  end

  def wait_for_completion
    @completion_mutex.synchronize do
      @completion_semaphore.wait(@completion_mutex) until @completed
    end
  end

  private

  def execution
    @execution ||= RowExecution.new(row: @row, workflow_execution: @workflow_execution)
  end

  def process_current_step
    current_step = @ordered_steps[@current_step_index]
    @current_step_executor = StepExecutor.new(
      current_step,
      row,
      row_execution: execution,
      hydra_manager: HydraManager.instance,
      on_complete: method(:handle_step_completion),
      priority: execution.processing?,
      step_templates: @step_templates
    )

    if @current_step_executor.should_skip?
      handle_step_completion(nil)
    else
      execution.start!
      @current_step_executor.call
    end
  end

  def handle_step_completion(result)
    # Handle skipped steps (nil result)
    result ||= { success: true, data: {} }

    if result[:success]
      Rails.logger.info "Row #{row.source_index} step #{@current_step_index} success"
      Rails.logger.info "  data: #{result[:data]}" if result[:data].present?
    else
      handle_step_failure(result[:error])
    end

    @current_step_index += 1

    if @current_step_index >= @ordered_steps.length
      execution.complete! unless execution.failed?
      mark_completed
    else
      call
    end
  end

  def handle_step_failure(error)
    current_step = @ordered_steps[@current_step_index]

    if @current_step_executor.required?
      Rails.logger.info("Row #{@row.source_index} required step #{current_step.name} failed: #{error}")
      execution.fail!
      row.update(status: :failed)
      mark_completed # Mark as completed even on failure
      return
    end

    Rails.logger.info("Row #{@row.source_index} non-required step #{current_step.name} failed: #{error}")
  end

  def mark_completed
    @completion_mutex.synchronize do
      @completed = true
      @completion_semaphore.broadcast
    end
  end
end

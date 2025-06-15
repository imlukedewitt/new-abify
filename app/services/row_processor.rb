# frozen_string_literal: true

# Runs a Workflow on a single Row,
# creating WorkflowStepExecutors for each step
class RowProcessor
  attr_reader :row, :workflow, :execution

  def initialize(row:, workflow:)
    raise ArgumentError, "row is required" if row.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?

    @row = row
    @workflow = workflow
    @ordered_steps = workflow.steps.sort_by(&:order)
    @current_step_index = 0
    @execution = find_or_create_execution
    @completion_semaphore = Thread::ConditionVariable.new
    @completion_mutex = Thread::Mutex.new
    @completed = false
  end

  def call
    if @execution.complete?
      mark_completed
      return
    end

    # TODO: this is messy, need to clean up with logic in #handle_step_completion
    if @ordered_steps.empty? || @current_step_index >= @ordered_steps.length
      @execution.complete!
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

  def find_or_create_execution
    RowExecution.find_or_create_by(row: @row)
  end

  def process_current_step
    current_step = @ordered_steps[@current_step_index]
    @current_step_processor = StepProcessor.new(
      current_step,
      row,
      hydra_manager: HydraManager.instance,
      on_complete: method(:handle_step_completion),
      priority: @execution.processing?, # prioritize completing in-progress rows
      auth_config: current_step.config&.dig('auth')
    )

    if @current_step_processor.should_skip?
      handle_step_completion(nil)
    else
      @execution.start!
      @current_step_processor.call
    end
  end

  def handle_step_completion(result)
    # Handle skipped steps (nil result)
    result ||= { success: true, data: {} }

    if result[:success]
      update_row_with_success_data(result[:data])
    else
      handle_step_failure(result[:error])
    end

    @current_step_index += 1

    # Check if we're done processing all steps
    if @current_step_index >= @ordered_steps.length
      # Only mark as complete if not already failed
      @execution.complete! unless @execution.failed?
      mark_completed
    else
      call
    end
  end

  def update_row_with_success_data(data)
    return if data.nil? || data.empty?

    row.data ||= {}
    row.data.merge!(data)
    row.save
  end

  def handle_step_failure(error)
    current_step = @ordered_steps[@current_step_index]

    if @current_step_processor.required?
      @execution.fail!
      row.update(status: :failed)
      mark_completed # Mark as completed even on failure
      return
    end

    Rails.logger.warn("Non-required step #{current_step.name} failed: #{error}")
  end

  def mark_completed
    @completion_mutex.synchronize do
      @completed = true
      @completion_semaphore.broadcast
    end
  end
end

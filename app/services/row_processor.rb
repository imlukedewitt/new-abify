# frozen_string_literal: true

# Runs a Workflow on a single Row,
# creating WorkflowStepExecutors for each step
class RowProcessor
  attr_reader :row, :workflow

  def initialize(row:, workflow:)
    raise ArgumentError, "row is required" if row.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?

    @row = row
    @workflow = workflow
    @ordered_steps = workflow.steps.sort_by(&:order)
    @current_step_index = 0
    @in_progress = false
  end

  def call
    if @ordered_steps.empty? || @current_step_index >= @ordered_steps.length
      @in_progress = false
      return
    end

    process_current_step
  end

  private

  def process_current_step
    current_step = @ordered_steps[@current_step_index]
    @current_step_processor = StepProcessor.new(
      current_step,
      row,
      hydra_manager: HydraManager.instance,
      on_complete: method(:handle_step_completion),
      priority: @in_progress
    )

    if @current_step_processor.should_skip?
      handle_step_completion(nil)
    else
      @in_progress = true
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
    call
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
      row.update(status: :failed)
      raise "Required step #{current_step.name} failed: #{error}"
    end

    # For non-required steps, we just continue processing
    Rails.logger.warn("Non-required step #{current_step.name} failed: #{error}")
  end
end

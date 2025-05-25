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
  end

  def call
    return if @ordered_steps.empty?
    return if @current_step_index >= @ordered_steps.length

    process_current_step
  end

  private

  def handle_step_completion(response)
    @current_step_index += 1
    call
  end

  def process_current_step
    current_step = @ordered_steps[@current_step_index]
    step_processor = StepProcessor.new(
      current_step,
      row,
      hydra_manager: HydraManager.instance,
      on_complete: method(:handle_step_completion)
    )
    step_processor.call
  end
end

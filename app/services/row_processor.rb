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
  end

  def call
    return if workflow.steps.empty?

    ordered_steps = workflow.steps.sort_by(&:order)
    current_step = ordered_steps.first
    step_processor = StepProcessor.new(
      current_step,
      row,
      hydra_manager: HydraManager.instance,
      on_complete: method(:handle_step_completion)
    )
    step_processor.call
  end

  private

  def handle_step_completion(response)
    # Will implement step completion handling in next iteration
  end
end

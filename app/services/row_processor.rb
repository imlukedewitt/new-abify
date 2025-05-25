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
  end
end
# frozen_string_literal: true

# Runs a Workflow on a single Row,
# creating WorkflowStepExecutors for each step
class RowProcessor
  attr_reader :row, :workflow

  def initialize(row:, workflow:)
    @row = row
    @workflow = workflow
  end
end

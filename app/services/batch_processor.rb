# frozen_string_literal: true

# .
class BatchProcessor
  attr_reader :batch, :workflow

  def initialize(batch:, workflow:)
    raise ArgumentError, "batch is required" if batch.nil?
    raise ArgumentError, "workflow is required" if workflow.nil?

    @batch = batch
    @workflow = workflow
  end

  def call
    batch.rows.each do |row|
      RowProcessor.new(row: row, workflow: workflow).call
    end
  end
end

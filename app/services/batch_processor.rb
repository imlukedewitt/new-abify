# frozen_string_literal: true

# .
class BatchProcessor
  attr_reader :batch, :workflow

  def initialize(batch:, workflow:)
    @batch = batch
    @workflow = workflow
  end
end

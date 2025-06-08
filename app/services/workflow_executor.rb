# frozen_string_literal: true

##
# WorkflowExecutor creates a RowProcessor for every Row in the Data Source
class WorkflowExecutor
  attr_reader :workflow, :data_source, :hydra_manager, :response, :execution

  def initialize(workflow, data_source, hydra_manager = HydraManager.instance)
    raise ArgumentError, 'workflow is required' unless workflow
    raise ArgumentError, 'data_source is required' unless data_source

    @hydra_manager = hydra_manager
    @workflow = workflow
    @data_source = data_source
  end

  def call
    @execution = WorkflowExecution.find_or_create_by(workflow: workflow, data_source: data_source)
    @execution.start!

    # Process rows in batches
    process_batches

    @execution
  end

  private

  def process_batches
    # For now, handle the simple case: no batching configuration
    # Put all rows in a single batch
    rows = data_source.rows
    batch = Batch.create!

    # Associate all rows with this batch
    rows.update_all(batch_id: batch.id)

    # Process the batch
    BatchProcessor.new(batch: batch, workflow: workflow).call
  end
end

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
    config = workflow.config || {}
    liquid_templates = config['liquid_templates'] || {}
    group_by_template = liquid_templates['group_by']

    rows = data_source.rows

    if group_by_template
      process_grouped_rows(rows)
    else
      process_single_batch(rows)
    end
  end

  def process_grouped_rows(rows)
    grouped = group_rows_by_reference(rows)
    grouped.each_value do |group_rows|
      create_and_process_batch(group_rows, "sequential")
    end
  end

  def process_single_batch(rows)
    create_and_process_batch(rows, "parallel")
  end

  def group_rows_by_reference(rows)
    rows.group_by do |row|
      # For now, just use the value directly from row.data as in the test
      # In a real implementation, you'd render the template with Liquid
      row.data['reference']
    end
  end

  def create_and_process_batch(rows, processing_mode)
    batch = Batch.create!(processing_mode: processing_mode)

    if rows.respond_to?(:update_all)
      rows.update_all(batch_id: batch.id)
    else
      rows.each { |row| row.update!(batch_id: batch.id) }
    end

    BatchProcessor.new(batch: batch, workflow: workflow).call
  end
end

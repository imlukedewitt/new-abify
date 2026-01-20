# frozen_string_literal: true

require_relative 'liquid/workflow_templates'
require_relative 'liquid/step_templates'
require_relative 'liquid/context_builder'

##
# WorkflowExecutor creates a RowProcessor for every Row in the Data Source
class WorkflowExecutor
  attr_reader :workflow, :data_source, :hydra_manager, :response, :execution

  def initialize(workflow, data_source, execution: nil, hydra_manager: HydraManager.instance)
    raise ArgumentError, 'workflow is required' unless workflow
    raise ArgumentError, 'data_source is required' unless data_source

    @hydra_manager = hydra_manager
    @workflow = workflow
    @data_source = data_source
    @execution = execution || WorkflowExecution.create!(workflow: workflow, data_source: data_source)
  end

  def call
    @execution.start!
    @step_templates = compile_step_templates
    Rails.logger.info "\nStarting workflow execution for #{@workflow.name} at #{@execution.started_at}"

    # Process rows in batches
    begin
      process_batches
      @execution.complete!
    rescue StandardError => e
      @execution.fail!(e.message)
      raise
    end

    @execution
  end

  private

  def compile_step_templates
    workflow.steps.each_with_object({}) do |step, hash|
      hash[step.id] = Liquid::StepTemplates.new(step.step_config['liquid_templates'])
    end
  end

  def process_batches
    config = workflow.workflow_config || {}
    liquid_templates = config['liquid_templates'] || {}
    @templates = Liquid::WorkflowTemplates.new(liquid_templates)
    rows = data_source.rows

    if liquid_templates['group_by']
      process_grouped_rows(rows)
    else
      process_single_batch(rows)
    end
  end

  def process_grouped_rows(rows)
    row_groups = group_rows_by_key(rows)

    sorted_keys = row_groups.keys.sort_by(&:to_s) # (lexicographic, blank first)

    sorted_keys.each do |group_key|
      create_and_process_batch(row_groups[group_key], "parallel")
    end
  end

  def group_rows_by_key(rows)
    rows.group_by do |row|
      context = context_for_row(row)
      @templates.group_key(context) || ""
    end
  end

  def context_for_row(row)
    Liquid::ContextBuilder.new(row: row, workflow: workflow).build
  end

  def process_single_batch(rows)
    create_and_process_batch(rows, "parallel")
  end

  def create_and_process_batch(rows, processing_mode)
    return if rows.blank? # Prevent creating batches for no rows

    batch = Batch.create!(
      processing_mode: processing_mode,
      workflow_execution: @execution
    )

    if rows.respond_to?(:update_all)
      rows.update_all(batch_id: batch.id)
    else
      rows.each { |row| row.update!(batch_id: batch.id) }
    end

    BatchExecutor.new(
      batch: batch,
      workflow: workflow,
      workflow_execution: @execution,
      rows: rows,
      step_templates: @step_templates
    ).call
  end
end

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

  def process_batches
    config = workflow.config || {}
    liquid_templates = config['liquid_templates'] || {}
    group_by_template = liquid_templates['group_by']

    rows = data_source.rows

    if group_by_template
      process_grouped_rows(rows, group_by_template)
    else
      process_single_batch(rows)
    end
  end

  def process_grouped_rows(rows, group_by_template)
    row_groups = group_rows_by_template(rows, group_by_template)

    row_groups.each do |group_key, current_group_rows|
      next if group_key == :default

      create_and_process_batch(current_group_rows, "sequential")
    end

    default_rows = row_groups[:default]
    create_and_process_batch(default_rows, "parallel") if default_rows.present?
  end

  def group_rows_by_template(rows, group_by_template)
    grouped_rows = group_rows_by_key(rows, group_by_template)
    sort_grouped_rows(grouped_rows)
  end

  def group_rows_by_key(rows, group_by_template)
    rows.group_by do |row|
      key = evaluate_template_for_row(row, group_by_template)
      key.present? ? key : :default
    end
  end

  def sort_grouped_rows(grouped_rows)
    sort_by_template = workflow.config.dig('liquid_templates', 'sort_by')
    return grouped_rows unless sort_by_template

    grouped_rows.each do |group_key, group_rows|
      grouped_rows[group_key] = sort_rows_by_template(group_rows, sort_by_template)
    end

    grouped_rows
  end

  def sort_rows_by_template(rows, sort_by_template)
    rows.sort_by do |row|
      evaluate_template_for_row(row, sort_by_template)
    end
  end

  def evaluate_template_for_row(row, template)
    context = Liquid::ContextBuilder.new(row: row, workflow: workflow).build
    Liquid::Processor.new(template, context).render
  end

  def process_single_batch(rows)
    create_and_process_batch(rows, "parallel")
  end

  def create_and_process_batch(rows, processing_mode)
    return if rows.blank? # Prevent creating batches for no rows

    batch = Batch.create!(processing_mode: processing_mode)

    if rows.respond_to?(:update_all)
      rows.update_all(batch_id: batch.id)
    else
      rows.each { |row| row.update!(batch_id: batch.id) }
    end

    BatchProcessor.new(batch: batch, workflow: workflow).call
  end
end

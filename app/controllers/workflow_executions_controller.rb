# frozen_string_literal: true

##
# WorkflowExecutionsController is responsible for creating workflow executions.
class WorkflowExecutionsController < ApiController
  def create
    workflow = find_workflow
    return unless workflow

    data_source = find_data_source
    return unless data_source

    process_workflow_execution(workflow, data_source)
    nil
  end

  private

  def find_workflow
    workflow = Workflow.find_by(id: params[:workflow_id])
    return workflow if workflow

    render json: { error: "Workflow not found" }, status: :unprocessable_content
    nil
  end

  def find_data_source
    data_source = DataSource.find_by(id: params[:data_source_id])
    return data_source if data_source

    render json: { error: "Data source not found" }, status: :unprocessable_content
    nil
  end

  def process_workflow_execution(workflow, data_source)
    workflow_execution = WorkflowExecutor.new(workflow, data_source).call
    render json: { workflow_execution_id: workflow_execution.id }, status: :created
  rescue StandardError => e
    render json: { error: "Processing error: #{e.message}" }, status: :unprocessable_content
  end
end

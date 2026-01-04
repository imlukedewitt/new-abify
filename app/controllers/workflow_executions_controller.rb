# frozen_string_literal: true

##
# WorkflowExecutionsController is responsible for creating workflow executions.
class WorkflowExecutionsController < ApplicationController
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
    identifier = params[:workflow_handle].presence || params[:workflow_id]
    workflow = Workflow.find_by_id_or_handle(identifier)
    return workflow if workflow

    respond_to do |format|
      format.json { render json: { error: 'Workflow not found' }, status: :unprocessable_content }
      format.html { redirect_to data_sources_path, alert: 'Workflow not found' }
    end
    nil
  end

  def find_data_source
    data_source = DataSource.find_by(id: params[:data_source_id])
    return data_source if data_source

    respond_to do |format|
      format.json { render json: { error: 'Data source not found' }, status: :unprocessable_content }
      format.html { redirect_to data_sources_path, alert: 'Data source not found' }
    end
    nil
  end

  def process_workflow_execution(workflow, data_source)
    workflow_execution = WorkflowExecutor.new(workflow, data_source).call
    respond_to do |format|
      format.json { render json: { workflow_execution_id: workflow_execution.id }, status: :created }
      format.html { redirect_to data_source_path(data_source), notice: "Workflow started" }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { error: "Processing error: #{e.message}" }, status: :unprocessable_content }
      format.html { redirect_to data_source_path(data_source), alert: "Error: #{e.message}" }
    end
  end
end

# frozen_string_literal: true

##
# WorkflowExecutionsController is responsible for creating workflow executions.
class WorkflowExecutionsController < ApplicationController
  def create
    workflow = find_workflow
    return unless workflow

    source = validate_source
    return render(source) if source.is_a?(Hash)

    process_workflow_execution(workflow, source)
    nil
  end

  private

  def find_workflow
    workflow = Workflow.find_by(id: params[:workflow_id])
    return workflow if workflow

    render json: { error: "Workflow not found" }, status: :unprocessable_entity
    nil
  end

  def validate_source
    source = params[:source]
    if source.nil? || !(source.is_a?(ActionDispatch::Http::UploadedFile) || source.is_a?(Rack::Test::UploadedFile))
      { json: { error: "Source is required or invalid" }, status: :bad_request }
    else
      source
    end
  end

  def process_workflow_execution(workflow, source)
    data_source = DataSources::Builder.call(source: source)
    workflow_execution = WorkflowExecutor.new(workflow, data_source).call
    render json: { workflow_execution_id: workflow_execution.id }, status: :created
  rescue DataSources::Builder::InvalidSourceError, CSV::MalformedCSVError => e
    render json: { error: "Invalid data source: #{e.message}" }, status: :bad_request
  rescue StandardError => e
    render json: { error: "Processing error: #{e.message}" }, status: :unprocessable_entity
  end
end

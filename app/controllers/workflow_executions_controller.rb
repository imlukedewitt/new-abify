# frozen_string_literal: true

##
# WorkflowExecutionsController is responsible for creating workflow executions.
class WorkflowExecutionsController < ApplicationController
  def create
    workflow = Workflow.find(params[:workflow_id])
    data_source = DataSources::Builder.call(source: params[:source])
    workflow_execution = WorkflowExecutor.new(workflow, data_source).call
    render json: { workflow_execution_id: workflow_execution.id }, status: :created
  end
end

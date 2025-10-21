# frozen_string_literal: true

## WorkflowsController
class WorkflowsController < ApplicationController
  def create
    workflow = Workflow.new(workflow_params)

    if workflow.save
      render json: { workflow_id: workflow.id }, status: :created
    else
      render json: { error: workflow.errors.full_messages.join(', ') }, status: :unprocessable_content
    end
  end

  private

  def workflow_params
    params.permit(:name, config: {})
  end
end

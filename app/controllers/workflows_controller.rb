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

  def index
    workflows = Workflow.all
    workflows = workflows.includes(:steps) if include_steps
    render json: { workflows: serialize_workflows(workflows) }
  end

  def show
    workflow = Workflow.find(params[:id])
    render json: { workflow: serialize_workflow(workflow) }
  rescue ActiveRecord::RecordNotFound => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def workflow_params
    params.permit(:name, config: {})
  end

  def serialize_workflows(workflows)
    workflows.map do |workflow|
      serialize_workflow(workflow)
    end
  end

  def serialize_workflow(workflow)
    {
      id: workflow.id,
      name: workflow.name,
      created_at: workflow.created_at,
      updated_at: workflow.updated_at
    }.tap do |the|
      the[:steps] = serialize_steps(workflow.steps) if include_steps
      the[:config] = workflow.config if include_config
    end
  end

  def serialize_steps(steps)
    steps.map do |step|
      {
        id: step.id,
        name: step.name,
        url: step.config["liquid_templates"]["url"],
        method: step.config["liquid_templates"]["method"]
      }
    end
  end

  def include_steps
    params[:include_steps].to_s.downcase == 'true'
  end

  def include_config
    params[:include_config].to_s.downcase == 'true'
  end
end

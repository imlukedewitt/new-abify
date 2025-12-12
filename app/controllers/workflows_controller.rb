# frozen_string_literal: true

## WorkflowsController
class WorkflowsController < ApiController
  include Serializable
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
    render json: { workflows: serialize_collection(workflows, serialization_options) }
  end

  def show
    workflow = Workflow.find(params[:id])
    render json: { workflow: serialize(workflow, serialization_options) }
  rescue ActiveRecord::RecordNotFound => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def workflow_params
    params.permit(:name, :connection_id, config: {}, steps_attributes: [:id, :name, { config: {} }])
  end

  def serialization_options
    {
      include_steps: include_steps,
      include_config: include_config
    }
  end

  def include_steps
    params[:include_steps].to_s.downcase == 'true'
  end

  def include_config
    params[:include_config].to_s.downcase == 'true'
  end
end

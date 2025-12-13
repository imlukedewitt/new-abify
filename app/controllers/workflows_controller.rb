# frozen_string_literal: true

## WorkflowsController
class WorkflowsController < ApiController
  include Serializable
  def create
    connection_error = validate_connection
    return render json: { error: connection_error }, status: :unprocessable_content if connection_error

    workflow = Workflow.new(workflow_params_with_connection)

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
    workflow = Workflow.find_by_id_or_handle!(params[:id])
    render json: { workflow: serialize(workflow, serialization_options) }
  rescue ActiveRecord::RecordNotFound => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def workflow_params
    params.permit(:name, :handle, :connection_id, :connection_handle, config: {},
                                                                      steps_attributes: [:id, :name, { config: {} }])
  end

  def workflow_params_with_connection
    permitted = workflow_params.except(:connection_handle)
    resolve_connection_from_handle(permitted)
  end

  def resolve_connection_from_handle(permitted)
    return permitted if params[:connection_handle].blank?
    return permitted if permitted[:connection_id].present?

    connection = Connection.find_by(handle: params[:connection_handle])
    permitted[:connection_id] = connection&.id
    permitted
  end

  def validate_connection
    if params[:connection_id].present?
      return "Connection not found" unless Connection.exists?(params[:connection_id])
    elsif params[:connection_handle].present?
      return "Connection not found" unless Connection.exists?(handle: params[:connection_handle])
    end
    nil
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

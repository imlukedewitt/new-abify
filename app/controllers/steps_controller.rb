# frozen_string_literal: true

## StepsController
class StepsController < ApiController
  def create
    workflow = Workflow.find(params[:workflow_id])
    connection_error = validate_connection
    return render json: { error: connection_error }, status: :unprocessable_content if connection_error

    step = workflow.steps.build(step_params_with_connection)

    if step.save
      render json: { step_id: step.id }, status: :created
    else
      render json: { error: step.errors.full_messages.join(', ') }, status: :unprocessable_content
    end
  end

  private

  def step_params
    params.require(:step).permit(:name, :order, :connection_id, :connection_handle, config: {})
  end

  def step_params_with_connection
    permitted = step_params.except(:connection_handle)
    resolve_connection_from_handle(permitted)
  end

  def resolve_connection_from_handle(permitted)
    return permitted if params.dig(:step, :connection_handle).blank?
    return permitted if permitted[:connection_id].present?

    connection = Connection.find_by(handle: params.dig(:step, :connection_handle))
    permitted[:connection_id] = connection&.id
    permitted
  end

  def validate_connection
    if params.dig(:step, :connection_id).present?
      return "Connection not found" unless Connection.exists?(params.dig(:step, :connection_id))
    elsif params.dig(:step, :connection_handle).present?
      return "Connection not found" unless Connection.exists?(handle: params.dig(:step, :connection_handle))
    end
    nil
  end
end

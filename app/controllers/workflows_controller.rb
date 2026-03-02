# frozen_string_literal: true

## WorkflowsController
class WorkflowsController < ApplicationController
  include Serializable

  def index
    @workflows = Workflow.includes(:steps).all

    respond_to do |format|
      format.html
      format.json do
        workflows = include_steps ? @workflows : Workflow.all
        render json: { workflows: serialize_collection(workflows, serialization_options) }
      end
    end
  end

  def show
    @workflow = Workflow.find_by_id_or_handle!(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: { workflow: serialize(@workflow, serialization_options) } }
    end
  end

  def new
    @workflow = Workflow.new
  end

  def edit
    @workflow = Workflow.find_by_id_or_handle!(params[:id])
  end

  def create
    @workflow = Workflow.new(workflow_params)

    return respond_with_errors(@workflow, :new) unless @workflow.save

    respond_to do |format|
      format.html { redirect_to workflow_path(@workflow), notice: 'Workflow created successfully' }
      format.json { render json: { workflow_id: @workflow.id }, status: :created }
    end
  end

  def update
    @workflow = Workflow.find_by_id_or_handle!(params[:id])

    return respond_with_errors(@workflow, :edit) unless @workflow.update(workflow_params)

    respond_to do |format|
      format.html { redirect_to workflow_path(@workflow), notice: 'Workflow updated successfully' }
      format.json { render json: { workflow: serialize(@workflow, serialization_options) } }
    end
  end

  def destroy
    @workflow = Workflow.find_by_id_or_handle!(params[:id])
    return respond_with_destroy_error unless @workflow.destroy

    respond_to do |format|
      format.html { redirect_to workflows_path, notice: 'Workflow deleted successfully' }
      format.json { head :no_content }
    end
  end

  private

  def workflow_params
    permitted = params.require(:workflow)
                      .permit(
                        :name, :handle,
                        config: {},
                        connection_slots: %i[handle description default],
                        steps_attributes: [:id, :name, { config: {} }]
                      )
    permitted[:connection_slots] = ConnectionSlot::Normalizer.call(permitted[:connection_slots])
    permitted
  end

  def respond_with_destroy_error
    respond_to do |format|
      format.html { redirect_to workflow_path(@workflow), alert: @workflow.errors.full_messages.join(', ') }
      format.json { render json: { errors: @workflow.errors.full_messages }, status: :unprocessable_content }
    end
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

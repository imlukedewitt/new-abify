# frozen_string_literal: true

## WorkflowsController
class WorkflowsController < ApplicationController
  include Serializable

  def index
    @workflows = Workflow.includes(:steps, :connection).all

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
    @connections = Connection.all

    respond_to do |format|
      format.html
      format.json { render json: { workflow: serialize(@workflow, serialization_options) } }
    end
  end

  def new
    @workflow = Workflow.new
    @connections = Connection.all
  end

  def edit
    @workflow = Workflow.find_by_id_or_handle!(params[:id])
    @connections = Connection.all
  end

  def create
    @workflow = Workflow.new(workflow_params)

    unless @workflow.save
      @connections = Connection.all
      return respond_with_errors(@workflow, :new)
    end

    respond_to do |format|
      format.html { redirect_to workflow_path(@workflow), notice: 'Workflow created successfully' }
      format.json { render json: { workflow_id: @workflow.id }, status: :created }
    end
  end

  def update
    @workflow = Workflow.find_by_id_or_handle!(params[:id])

    unless @workflow.update(workflow_params)
      @connections = Connection.all
      return respond_with_errors(@workflow, :edit)
    end

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
    params.require(:workflow)
          .permit(
            :name, :handle, :connection_id, :connection_handle,
            config: {},
            steps_attributes: [:id, :name, { config: {} }]
          )
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

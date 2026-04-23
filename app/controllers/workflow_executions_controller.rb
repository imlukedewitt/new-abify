# frozen_string_literal: true

##
# WorkflowExecutionsController is responsible for creating workflow executions.
class WorkflowExecutionsController < ApplicationController
  before_action :set_workflow, only: %i[create new]
  before_action :set_data_source, only: :create

  def index
    @pagy, @workflow_executions = pagy(:offset, WorkflowExecution.order(id: :desc))
    respond_to do |format|
      format.json { render json: { workflow_executions: @workflow_executions } }
      format.html { render :index }
    end
  end

  def show
    @workflow_execution = WorkflowExecution.find(params[:id])
    row_executions = @workflow_execution.row_executions.includes(:step_executions).order(id: :desc)
    @pagy, @row_executions = pagy(:offset, row_executions)

    respond_to do |format|
      format.json { render json: { workflow_execution: @workflow_execution } }
      format.html { render :show }
    end
  end

  def new
    set_connections
    @workflow_execution = WorkflowExecution.new(workflow: @workflow)
    respond_to do |format|
      format.html { render :new }
      format.json { render json: { workflow: @workflow, connections: @connections } }
    end
  end

  def create
    return if performed?

    @workflow_execution = WorkflowExecution.new(workflow_execution_params)
    @workflow_execution.workflow = @workflow
    @workflow_execution.data_source = @data_source

    # Enrich mappings with audit data (name, handle) before saving
    if @workflow.connection_slots.present?
      @workflow_execution.connection_mappings = ConnectionMapping::Normalizer.call(
        workflow: @workflow,
        raw_mappings: @workflow_execution.connection_mappings || {}
      )
    end

    if @workflow_execution.save
      # TODO: Replace with proper background job (Sidekiq/ActiveJob)
      user_id = Current.user&.id
      Thread.new do
        Current.user = User.find(user_id) if user_id
        WorkflowExecutor.new(@workflow, @data_source, execution: @workflow_execution).call
      rescue StandardError => e
        Rails.logger.error "Workflow execution failed: #{e.message}"
      end

      respond_to do |format|
        format.json do
          render json: { message: 'Workflow started', workflow_execution_id: @workflow_execution.id }, status: :accepted
        end
        format.html { redirect_to data_source_path(@data_source), notice: 'Workflow started' }
      end
    else
      set_connections
      respond_with_errors(@workflow_execution, :new)
    end
  end

  private

  def set_connections
    @connections = Current.user.connections.order(:name)
  end

  def workflow_execution_params
    params.fetch(:workflow_execution, {}).permit(connection_mappings: {})
  end

  def set_workflow
    identifier = params[:workflow_handle].presence || params[:workflow_id]
    @workflow = Workflow.find_by_id_or_handle(identifier)
    render_not_found('Workflow') unless @workflow
  end

  def set_data_source
    @data_source = DataSource.find_by(id: params[:data_source_id])
    render_not_found('Data source') unless @data_source
  end

  def render_not_found(resource)
    respond_to do |format|
      format.json { render json: { error: "#{resource} not found" }, status: :unprocessable_content }
      format.html { redirect_to data_sources_path, alert: "#{resource} not found" }
    end
  end
end

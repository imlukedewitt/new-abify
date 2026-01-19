# frozen_string_literal: true

##
# WorkflowExecutionsController is responsible for creating workflow executions.
class WorkflowExecutionsController < ApplicationController
  before_action :set_workflow, only: :create
  before_action :set_data_source, only: :create

  def index
    @workflow_executions = WorkflowExecution.all
    respond_to do |format|
      format.json { render json: { workflow_executions: @workflow_executions } }
      format.html { render :index }
    end
  end

  def show
    @workflow_execution = WorkflowExecution.find(params[:id])
    respond_to do |format|
      format.json { render json: { workflow_execution: @workflow_execution } }
      format.html { render :show }
    end
  end

  def create
    return if performed?

    # TODO: Replace with proper background job (Sidekiq/ActiveJob)
    Thread.new do
      WorkflowExecutor.new(@workflow, @data_source, execution: execution).call
    rescue StandardError => e
      Rails.logger.error "Workflow execution failed: #{e.message}"
    end

    respond_to do |format|
      format.json { render json: { message: 'Workflow started', workflow_execution_id: execution.id }, status: :accepted }
      format.html { redirect_to data_source_path(@data_source), notice: 'Workflow started' }
    end
  end

  private

  def execution
    @execution ||= WorkflowExecution.create!(workflow: @workflow, data_source: @data_source)
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

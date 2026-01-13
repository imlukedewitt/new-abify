# frozen_string_literal: true

## StepsController
class StepsController < ApplicationController
  before_action :set_workflow
  before_action :set_step, only: %i[show edit update destroy move_up move_down]
  before_action :set_connections, only: %i[show new edit create update]

  def index
    redirect_to workflow_path(@workflow)
  end

  def show; end

  def new
    @step = @workflow.steps.build
  end

  def edit; end

  def create
    @step = @workflow.steps.build(step_params)
    return respond_with_errors(@step, :new) unless @step.save

    respond_to do |format|
      format.html { redirect_to workflow_step_path(@workflow, @step), notice: 'Step created successfully' }
      format.json { render json: { step_id: @step.id }, status: :created }
    end
  end

  def update
    return respond_with_errors(@step, :edit) unless @step.update(step_params)

    respond_to do |format|
      format.html { redirect_to workflow_step_path(@workflow, @step), notice: 'Step updated successfully' }
      format.json { render json: { step_id: @step.id } }
    end
  end

  def destroy
    return respond_with_destroy_error unless @step.destroy

    respond_to do |format|
      format.html { redirect_to workflow_path(@workflow), notice: 'Step deleted successfully' }
      format.json { head :no_content }
    end
  end

  def move_up
    swap_previous_step
    redirect_to workflow_path(@workflow)
  end

  def move_down
    swap_next_step
    redirect_to workflow_path(@workflow)
  end

  private

  def set_workflow
    @workflow = Workflow.find(params[:workflow_id])
  end

  def set_step
    @step = @workflow.steps.unscoped.find(params[:id])
  end

  def set_connections
    @connections = Connection.all
  end

  def respond_with_destroy_error
    respond_to do |format|
      format.html { redirect_to workflow_step_path(@workflow, @step), alert: @step.errors.full_messages.join(', ') }
      format.json { render json: { errors: @step.errors.full_messages }, status: :unprocessable_entity }
    end
  end

  def step_params
    params.require(:step)
          .permit(
            :name, :order, :connection_id, :connection_handle,
            config: { liquid_templates: %i[name url method body params skip_condition success_data required] }
          )
  end

  def swap_previous_step
    previous_step = @workflow.steps.unscoped.where('"order" < ?', @step.order).order(order: :desc).first
    return unless previous_step

    swap_steps(@step, previous_step)
  end

  def swap_next_step
    next_step = @workflow.steps.unscoped.where('"order" > ?', @step.order).order(order: :asc).first
    return unless next_step

    swap_steps(@step, next_step)
  end

  def swap_steps(step_a, step_b)
    Step.transaction do
      temp_order = step_a.order
      step_a.update!(order: step_b.order)
      step_b.update!(order: temp_order)
    end
  end
end

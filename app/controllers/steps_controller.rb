# frozen_string_literal: true

## StepsController
class StepsController < ApplicationController
  def create
    workflow = Workflow.find(params[:workflow_id])
    step = workflow.steps.build(step_params)

    if step.save
      render json: { step_id: step.id }, status: :created
    else
      render json: { error: step.errors.full_messages.join(', ') }, status: :unprocessable_content
    end
  end

  private

  def step_params
    params.require(:step).permit(:name, :order, config: {})
  end
end

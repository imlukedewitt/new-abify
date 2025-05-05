class AddWorkflowRefToWorkflowSteps < ActiveRecord::Migration[8.0]
  def change
    add_reference :workflow_steps, :workflow, null: false, foreign_key: true
  end
end

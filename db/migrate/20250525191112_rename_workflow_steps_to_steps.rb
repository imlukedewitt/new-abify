class RenameWorkflowStepsToSteps < ActiveRecord::Migration[8.0]
  def change
    rename_table :workflow_steps, :steps
  end
end

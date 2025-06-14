class AddWorkflowExecutionIdToBatches < ActiveRecord::Migration[8.0]
  def change
    add_reference :batches, :workflow_execution, null: true, foreign_key: true
  end
end

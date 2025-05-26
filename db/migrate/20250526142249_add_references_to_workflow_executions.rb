class AddReferencesToWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    add_reference :workflow_executions, :workflow, null: false, foreign_key: true
    add_reference :workflow_executions, :data_source, null: false, foreign_key: true
    add_column :workflow_executions, :status, :string, default: 'pending'
  end
end

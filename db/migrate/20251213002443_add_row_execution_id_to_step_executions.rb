class AddRowExecutionIdToStepExecutions < ActiveRecord::Migration[8.0]
  def change
    add_reference :step_executions, :row_execution, null: true, foreign_key: true
  end
end

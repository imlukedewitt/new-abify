class AddConnectionMappingsToWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :workflow_executions, :connection_mappings, :json, default: {}
  end
end

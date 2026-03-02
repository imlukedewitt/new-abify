class AddConfigToWorkflowSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :workflow_steps, :config, :json
    add_column :workflow_steps, :position, :integer
    add_column :workflow_steps, :name, :string
  end
end

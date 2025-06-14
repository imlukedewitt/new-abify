class CreateWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_executions do |t|
      t.references :workflow, null: false, foreign_key: true
      t.references :data_source, null: false, foreign_key: true
      t.string :status, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end
  end
end

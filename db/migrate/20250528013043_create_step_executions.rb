class CreateStepExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :step_executions do |t|
      t.references :step, null: false, foreign_key: true
      t.references :row, null: false, foreign_key: true
      t.string :status, default: 'pending'
      t.json :result
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end

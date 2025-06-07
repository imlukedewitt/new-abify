class CreateRowExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :row_executions do |t|
      t.references :row, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    # Add index for faster querying
    add_index :row_executions, :status
  end
end

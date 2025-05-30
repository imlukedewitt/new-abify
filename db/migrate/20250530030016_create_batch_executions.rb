class CreateBatchExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :batch_executions do |t|
      t.references :batch, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end

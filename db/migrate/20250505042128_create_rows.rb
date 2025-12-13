class CreateRows < ActiveRecord::Migration[8.0]
  def change
    create_table :rows do |t|
      t.references :data_source, null: false, foreign_key: true
      t.json :data
      t.string :status
      t.integer :source_index

      t.timestamps
    end
  end
end

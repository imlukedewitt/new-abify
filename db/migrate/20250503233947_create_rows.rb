class CreateRows < ActiveRecord::Migration[8.0]
  def change
    create_table :rows do |t|
      t.timestamps
    end
  end
end

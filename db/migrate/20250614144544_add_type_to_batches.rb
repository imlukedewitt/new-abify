class AddTypeToBatches < ActiveRecord::Migration[8.0]
  def change
    add_column :batches, :processing_mode, :string
  end
end

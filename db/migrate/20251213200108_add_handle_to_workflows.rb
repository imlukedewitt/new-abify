class AddHandleToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :handle, :string
    add_index :workflows, :handle, unique: true
  end
end

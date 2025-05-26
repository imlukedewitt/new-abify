class AddNameToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :name, :string
  end
end

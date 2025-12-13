class RemoveStatusFromRows < ActiveRecord::Migration[8.0]
  def change
    remove_column :rows, :status, :string
  end
end

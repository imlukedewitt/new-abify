class RemoveOriginalDataFromRows < ActiveRecord::Migration[8.0]
  def change
    remove_column :rows, :original_data, :json
  end
end

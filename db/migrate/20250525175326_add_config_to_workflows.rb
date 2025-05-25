class AddConfigToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :config, :json
  end
end

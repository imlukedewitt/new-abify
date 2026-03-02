class AddConnectionSlotsToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :connection_slots, :json, default: []
  end
end

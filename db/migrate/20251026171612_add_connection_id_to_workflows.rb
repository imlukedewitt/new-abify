# frozen_string_literal: true

class AddConnectionIdToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_reference :workflows, :connection, null: true, foreign_key: { on_delete: :nullify }
  end
end

class AddConnectionIdToSteps < ActiveRecord::Migration[8.0]
  def change
    add_reference :steps, :connection, foreign_key: { on_delete: :nullify }
  end
end

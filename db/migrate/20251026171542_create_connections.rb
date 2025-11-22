# frozen_string_literal: true

class CreateConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :handle, null: false
      t.text :credentials, null: false
      t.string :subdomain
      t.string :domain

      t.timestamps
    end

    add_index :connections, %i[user_id handle], unique: true
  end
end

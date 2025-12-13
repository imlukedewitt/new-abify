# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_13_202441) do
  create_table "batch_executions", force: :cascade do |t|
    t.integer "batch_id", null: false
    t.integer "workflow_id", null: false
    t.string "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_batch_executions_on_batch_id"
    t.index ["workflow_id"], name: "index_batch_executions_on_workflow_id"
  end

  create_table "batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "processing_mode"
    t.integer "workflow_execution_id"
    t.index ["workflow_execution_id"], name: "index_batches_on_workflow_execution_id"
  end

  create_table "connections", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.string "handle", null: false
    t.text "credentials", null: false
    t.string "subdomain"
    t.string "domain"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "handle"], name: "index_connections_on_user_id_and_handle", unique: true
    t.index ["user_id"], name: "index_connections_on_user_id"
  end

  create_table "data_sources", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "row_executions", force: :cascade do |t|
    t.integer "row_id", null: false
    t.integer "workflow_execution_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["row_id"], name: "index_row_executions_on_row_id"
    t.index ["status"], name: "index_row_executions_on_status"
    t.index ["workflow_execution_id"], name: "index_row_executions_on_workflow_execution_id"
  end

  create_table "rows", force: :cascade do |t|
    t.integer "data_source_id", null: false
    t.json "data"
    t.integer "source_index"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "batch_id"
    t.index ["batch_id"], name: "index_rows_on_batch_id"
    t.index ["data_source_id"], name: "index_rows_on_data_source_id"
  end

  create_table "step_executions", force: :cascade do |t|
    t.integer "step_id", null: false
    t.integer "row_id", null: false
    t.string "status", default: "pending"
    t.json "result"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "row_execution_id"
    t.index ["row_execution_id"], name: "index_step_executions_on_row_execution_id"
    t.index ["row_id"], name: "index_step_executions_on_row_id"
    t.index ["step_id"], name: "index_step_executions_on_step_id"
  end

  create_table "steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_id", null: false
    t.json "config"
    t.integer "order"
    t.string "name"
    t.integer "connection_id"
    t.index ["connection_id"], name: "index_steps_on_connection_id"
    t.index ["workflow_id"], name: "index_steps_on_workflow_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "workflow_executions", force: :cascade do |t|
    t.integer "workflow_id", null: false
    t.integer "data_source_id", null: false
    t.string "status", default: "pending"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_workflow_executions_on_data_source_id"
    t.index ["workflow_id"], name: "index_workflow_executions_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "config"
    t.string "name"
    t.integer "connection_id"
    t.string "handle"
    t.index ["connection_id"], name: "index_workflows_on_connection_id"
    t.index ["handle"], name: "index_workflows_on_handle", unique: true
  end

  add_foreign_key "batch_executions", "batches"
  add_foreign_key "batch_executions", "workflows"
  add_foreign_key "batches", "workflow_executions"
  add_foreign_key "connections", "users"
  add_foreign_key "row_executions", "rows"
  add_foreign_key "row_executions", "workflow_executions"
  add_foreign_key "rows", "batches"
  add_foreign_key "rows", "data_sources"
  add_foreign_key "step_executions", "row_executions"
  add_foreign_key "step_executions", "rows"
  add_foreign_key "step_executions", "steps"
  add_foreign_key "steps", "connections", on_delete: :nullify
  add_foreign_key "steps", "workflows"
  add_foreign_key "workflow_executions", "data_sources"
  add_foreign_key "workflow_executions", "workflows"
  add_foreign_key "workflows", "connections", on_delete: :nullify
end

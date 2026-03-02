# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecution, type: :model do
  let(:user) { create(:user) }
  let(:connection) { create(:connection, user: user, name: 'Name', handle: 'handle') }
  let(:workflow) { create(:workflow, connection_slots: [{ 'handle' => 'slot', 'description' => 'Slot' }]) }

  before do
    Current.user = user
  end

  describe 'attributes' do
    it 'has connection_mappings' do
      execution = WorkflowExecution.new
      expect(execution).to respond_to(:connection_mappings)
    end

    it 'defaults connection_mappings to an empty hash' do
      execution = WorkflowExecution.new
      expect(execution.connection_mappings).to eq({})
    end
  end

  describe 'validations' do
    it 'is valid with a properly structured hash for connection_mappings' do
      mappings = {
        'slot' => {
          'connection_id' => connection.id,
          'connection_name' => connection.name,
          'connection_handle' => connection.handle
        }
      }
      execution = build(:workflow_execution, workflow: workflow, connection_mappings: mappings)
      expect(execution).to be_valid
    end

    it 'is invalid if connection_mappings is not a hash' do
      execution = build(:workflow_execution, connection_mappings: 'not-a-hash')
      expect(execution).not_to be_valid
      expect(execution.errors[:connection_mappings]).to include('must be a hash')
    end

    it 'is invalid if a mapping is missing required keys' do
      execution = build(:workflow_execution, workflow: workflow,
                                             connection_mappings: { 'slot' => { 'connection_id' => connection.id } })
      expect(execution).not_to be_valid
      expect(execution.errors[:connection_mappings]).to include("mapping for 'slot' is missing required key: connection_name")
      expect(execution.errors[:connection_mappings]).to include("mapping for 'slot' is missing required key: connection_handle")
    end
  end

  describe 'connection_mappings persistence' do
    let(:db_connection) { create(:connection, user: user, name: 'Production DB', handle: 'prod-db') }
    let(:workflow_with_db) do
      create(:workflow, connection_slots: [{ 'handle' => 'primary_db', 'description' => 'DB' }])
    end

    it 'persists a hash of connection metadata' do
      mappings = {
        'primary_db' => {
          'connection_id' => db_connection.id,
          'connection_name' => db_connection.name,
          'connection_handle' => db_connection.handle
        }
      }

      execution = create(:workflow_execution, workflow: workflow_with_db, connection_mappings: mappings)

      expect(execution.reload.connection_mappings).to eq(mappings.transform_values { |v| v.transform_keys(&:to_s) })
    end

    it 'can be created using the :with_connection_mappings trait' do
      execution = create(:workflow_execution, :with_connection_mappings)
      expect(execution.connection_mappings).to have_key('primary_db')
      expect(execution.connection_mappings['primary_db']).to include(
        'connection_name' => 'Primary Database'
      )
    end

    it 'works correctly for existing records with empty mappings' do
      # Create with a workflow that has no slots, so it's valid with {}
      execution = create(:workflow_execution, workflow: create(:workflow, connection_slots: []))
      expect(execution.connection_mappings).to eq({})

      # Now update it to a workflow with slots and provide mappings
      new_workflow = create(:workflow, connection_slots: [{ 'handle' => 'new', 'description' => 'New' }])
      execution.workflow = new_workflow

      mappings = {
        'new' => {
          'connection_id' => connection.id,
          'connection_name' => connection.name,
          'connection_handle' => connection.handle
        }
      }
      execution.update!(connection_mappings: mappings)
      expect(execution.reload.connection_mappings['new']['connection_id']).to eq(connection.id)
    end
  end
end

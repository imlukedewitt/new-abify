# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecution, type: :model do
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
          'connection_id' => 1,
          'connection_name' => 'Name',
          'connection_handle' => 'handle'
        }
      }
      execution = build(:workflow_execution, connection_mappings: mappings)
      expect(execution).to be_valid
    end

    it 'is invalid if connection_mappings is not a hash' do
      execution = build(:workflow_execution, connection_mappings: 'not-a-hash')
      expect(execution).not_to be_valid
      expect(execution.errors[:connection_mappings]).to include('must be a hash')
    end

    it 'is invalid if a mapping is missing required keys' do
      execution = build(:workflow_execution, connection_mappings: { 'slot' => { 'connection_id' => 1 } })
      expect(execution).not_to be_valid
      expect(execution.errors[:connection_mappings]).to include("mapping for 'slot' is missing required key: connection_name")
      expect(execution.errors[:connection_mappings]).to include("mapping for 'slot' is missing required key: connection_handle")
    end
  end

  describe 'connection_mappings persistence' do
    it 'persists a hash of connection metadata' do
      mappings = {
        'primary_db' => {
          'connection_id' => 123,
          'connection_name' => 'Production DB',
          'connection_handle' => 'prod-db'
        }
      }

      execution = create(:workflow_execution, connection_mappings: mappings)

      expect(execution.reload.connection_mappings).to eq(mappings)
    end

    it 'can be created using the :with_connection_mappings trait' do
      execution = create(:workflow_execution, :with_connection_mappings)
      expect(execution.connection_mappings).to have_key('primary_db')
      expect(execution.connection_mappings['primary_db']).to include(
        'connection_name' => 'Primary Database'
      )
    end

    it 'works correctly for existing records with empty mappings' do
      execution = create(:workflow_execution) # defaults to {}
      expect(execution.connection_mappings).to eq({})

      # Verify we can update it later
      mappings = {
        'new' => {
          'connection_id' => 1,
          'connection_name' => 'Name',
          'connection_handle' => 'handle'
        }
      }
      execution.update!(connection_mappings: mappings)
      expect(execution.reload.connection_mappings['new']['connection_id']).to eq(1)
    end
  end
end

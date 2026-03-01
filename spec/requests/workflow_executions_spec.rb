# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkflowExecutions', type: :request do
  let(:user) { create(:user) }
  let(:workflow) { create(:workflow) }
  let(:data_source) { create(:data_source) }

  describe 'GET /workflow_executions/new' do
    let(:workflow_with_slots) do
      create(:workflow, connection_slots: [
               { 'handle' => 'test_slot', 'description' => 'Test Slot Description' }
             ])
    end

    it 'renders the connection mapping fields when slots are present' do
      get "/workflow_executions/new?workflow_id=#{workflow_with_slots.id}"
      expect(response).to be_successful
      expect(response.body).to include('Connection Mapping')
      expect(response.body).to include('test_slot')
      expect(response.body).to include('Test Slot Description')
    end

    it 'does not render connection mapping section when no slots' do
      get "/workflow_executions/new?workflow_id=#{workflow.id}"
      expect(response).to be_successful
      expect(response.body).not_to include('Connection Mapping')
    end
  end

  describe 'POST /workflow_executions' do
    it 'creates a new WorkflowExecution' do
      post '/workflow_executions', params: { workflow_id: workflow.id, data_source_id: data_source.id }, as: :json
      expect(response).to have_http_status(:accepted)
      expect(JSON.parse(response.body)).to have_key('workflow_execution_id')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutionsController, type: :controller do
  render_views

  describe 'GET #new' do
    let(:workflow) { create(:workflow, :with_handle) }
    let(:user) { User.last }

    it 'returns a successful response' do
      get :new, params: { workflow_id: workflow.id }
      expect(response).to be_successful
      expect(response.body).to include('Execute Workflow')
    end

    it 'returns a successful response (JSON)' do
      get :new, params: { workflow_id: workflow.id }, as: :json
      expect(response).to be_successful
      json_response = JSON.parse(response.body)
      expect(json_response['workflow']['id']).to eq(workflow.id)
      expect(json_response).to have_key('connections')
    end

    it 'loads only connections owned by the user' do
      # User is already created and authenticated by set_auth_header in before(:each)
      current_user = User.last

      other_user = create(:user)
      create(:connection, user: other_user, name: 'Other Connection')
      my_connection = create(:connection, user: current_user, name: 'My Connection')

      get :new, params: { workflow_id: workflow.id }, as: :json
      json_response = JSON.parse(response.body)
      connection_ids = json_response['connections'].map { |c| c['id'] }
      expect(connection_ids).to include(my_connection.id)
      expect(connection_ids).not_to include(other_user.connections.first.id)
    end
  end

  describe 'GET #index' do
    let!(:execution1) { create(:workflow_execution) }
    let!(:execution2) { create(:workflow_execution) }

    it 'returns all workflow executions' do
      get :index, as: :json
      expect(response).to be_successful
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('workflow_executions')
      expect(json_response['workflow_executions'].count).to eq(2)
    end
  end

  describe 'GET #show' do
    let!(:execution) { create(:workflow_execution) }

    context 'with valid execution id' do
      it 'returns the workflow execution' do
        get :show, params: { id: execution.id }, as: :json
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('workflow_execution')
        expect(json_response['workflow_execution']['id']).to eq(execution.id)
      end
    end

    context 'with invalid execution id' do
      it 'returns not found' do
        get :show, params: { id: 99_999 }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:workflow) { create(:workflow, :with_handle) }
    let(:data_source) { create(:data_source) }

    context 'with valid parameters' do
      let(:connection) { create(:connection, user: User.last) }
      let(:workflow_with_slots) do
        create(:workflow, :with_handle, connection_slots: [
                 { 'handle' => 'test_slot', 'description' => 'Test Slot' }
               ])
      end

      it 'creates a new workflow execution with connection mappings' do
        post :create, params: {
          workflow_id: workflow_with_slots.id,
          data_source_id: data_source.id,
          workflow_execution: {
            connection_mappings: {
              'test_slot' => {
                'connection_id' => connection.id,
                'connection_name' => connection.name,
                'connection_handle' => connection.handle
              }
            }
          }
        }, as: :json

        expect(response).to have_http_status(:accepted)
        execution = WorkflowExecution.last
        expect(execution.connection_mappings).to be_present
        expect(execution.connection_mappings['test_slot']['connection_id'].to_i).to eq(connection.id)
      end

      it 'creates a new workflow execution with workflow_id' do
        post :create, params: {
          workflow_id: workflow.id,
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:accepted)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('message')
        expect(json_response['message']).to eq('Workflow started')
        expect(json_response).to have_key('workflow_execution_id')
      end

      it 'creates a new workflow execution with workflow_handle' do
        post :create, params: {
          workflow_handle: workflow.handle,
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:accepted)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('workflow_execution_id')
      end

      it 'prefers workflow_handle over workflow_id when both provided' do
        other_workflow = create(:workflow, :with_handle)

        post :create, params: {
          workflow_id: other_workflow.id,
          workflow_handle: workflow.handle,
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:accepted)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('workflow_execution_id')
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable entity when connection mappings are missing for required slots' do
        workflow_with_slots = create(:workflow, :with_handle, connection_slots: [
                                       { 'handle' => 'required_slot', 'description' => 'Required' }
                                     ])

        post :create, params: {
          workflow_id: workflow_with_slots.id,
          data_source_id: data_source.id,
          workflow_execution: { connection_mappings: {} }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['errors']).to include("Connection mappings Missing mapping for slot 'required_slot'")
      end

      it 'returns unprocessable entity when connection is not owned by user' do
        connection_other_user = create(:connection) # belongs to different user
        workflow_with_slots = create(:workflow, :with_handle, connection_slots: [
                                       { 'handle' => 'test_slot', 'description' => 'Test Slot' }
                                     ])

        post :create, params: {
          workflow_id: workflow_with_slots.id,
          data_source_id: data_source.id,
          workflow_execution: {
            connection_mappings: {
              'test_slot' => {
                'connection_id' => connection_other_user.id,
                'connection_name' => connection_other_user.name,
                'connection_handle' => connection_other_user.handle
              }
            }
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['errors']).to include("Connection mappings Connection for slot 'test_slot' not found")
      end

      it 'returns unprocessable entity when workflow is not found' do
        post :create, params: {
          workflow_id: 'invalid_id',
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Workflow not found' })
      end

      it 'returns unprocessable entity when workflow_handle is not found' do
        post :create, params: {
          workflow_handle: 'nonexistent-handle',
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Workflow not found' })
      end

      it 'returns unprocessable entity when data source is not found' do
        post :create, params: {
          workflow_id: workflow.id,
          data_source_id: 'invalid_id'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Data source not found' })
      end

      it 'returns unprocessable entity when data source is missing' do
        post :create, params: {
          workflow_id: workflow.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Data source not found' })
      end
    end
  end
end

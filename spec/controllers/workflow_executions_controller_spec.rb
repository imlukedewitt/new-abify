# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutionsController, type: :controller do
  describe 'POST #create' do
    let(:workflow) { create(:workflow, :with_handle) }
    let(:data_source) { create(:data_source) }

    context 'with valid parameters' do
      it 'creates a new workflow execution with workflow_id' do
        post :create, params: {
          workflow_id: workflow.id,
          data_source_id: data_source.id
        }

        if response.status != 201
          puts "Response status: #{response.status}"
          puts "Response body: #{response.body}"
        end
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('workflow_execution_id')
        expect(json_response['workflow_execution_id']).to be_present
      end

      it 'creates a new workflow execution with workflow_handle' do
        post :create, params: {
          workflow_handle: workflow.handle,
          data_source_id: data_source.id
        }

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('workflow_execution_id')
      end

      it 'prefers workflow_handle over workflow_id when both provided' do
        other_workflow = create(:workflow, :with_handle)

        post :create, params: {
          workflow_id: other_workflow.id,
          workflow_handle: workflow.handle,
          data_source_id: data_source.id
        }

        expect(response).to have_http_status(:created)
        execution = WorkflowExecution.last
        expect(execution.workflow_id).to eq(workflow.id)
      end
    end

    context 'with invalid parameters' do
      it "returns unprocessable entity when workflow is not found" do
        post :create, params: {
          workflow_id: "invalid_id",
          data_source_id: data_source.id
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ "error" => "Workflow not found" })
      end

      it "returns unprocessable entity when workflow_handle is not found" do
        post :create, params: {
          workflow_handle: "nonexistent-handle",
          data_source_id: data_source.id
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ "error" => "Workflow not found" })
      end

      it 'returns unprocessable entity when data source is not found' do
        post :create, params: {
          workflow_id: workflow.id,
          data_source_id: "invalid_id"
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ "error" => "Data source not found" })
      end

      it 'returns unprocessable entity when data source is missing' do
        post :create, params: {
          workflow_id: workflow.id
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to eq({ "error" => "Data source not found" })
      end
    end
  end
end

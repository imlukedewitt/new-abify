# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutionsController, type: :controller do
  describe 'POST #create' do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }

    context 'with valid parameters' do
      it 'creates a new workflow execution' do
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

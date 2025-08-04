# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutionsController, type: :controller do
  describe 'POST #create' do
    let(:workflow) { create(:workflow) }
    let(:valid_source) { fixture_file_upload(Rails.root.join('spec/fixtures/files/3_rows.csv'), 'text/csv') }

    context 'with valid parameters' do
      it 'creates a new workflow execution' do
        post :create, params: {
          workflow_id: workflow.id,
          source: valid_source
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
          source: valid_source
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq({ "error" => "Workflow not found" })
      end

      it 'returns bad request when source is missing' do
        post :create, params: {
          workflow_id: workflow.id
        }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request when source is invalid' do
        invalid_source = fixture_file_upload(Rails.root.join('spec/fixtures/files/malformed.csv'), 'text/csv')

        post :create, params: {
          workflow_id: workflow.id,
          source: invalid_source
        }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end

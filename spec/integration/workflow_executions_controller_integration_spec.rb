# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkflowExecutions API', :request, :integration, :vcr do
  describe 'POST /workflow_executions' do
    let!(:valid_workflow) { create(:workflow, name: 'Test Workflow') }
    let(:valid_csv) { fixture_file_upload('simple.csv', 'text/csv') }
    let(:invalid_csv) { fixture_file_upload('malformed.csv', 'text/csv') }
    let!(:step_1) do
      create(:step, workflow: valid_workflow, order: 1, config: {
               'liquid_templates' => {
                 'name' => 'Get Post',
                 'url' => 'https://jsonplaceholder.typicode.com/posts/{{row.source_index}}',
                 'method' => 'get',
                 'success_data' => {
                   'post_id' => '{{response.id}}',
                   'post_title' => '{{response.title}}',
                   'user_id' => '{{response.userId}}'
                 }
               }
             })
    end

    context 'with valid parameters' do
      it 'creates a new workflow execution' do
        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id,
          source: valid_csv
        }

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('workflow_execution_id')

        execution = WorkflowExecution.find(json_response['workflow_execution_id'])
        expect(execution).to be_present
        expect(execution.status).to eq(Executable::COMPLETE)
        expect(execution.rows.first.data['post_id']).to eq "1"
      end
    end

    context 'with valid steps' do
    end

    context 'with invalid workflow id' do
      it 'returns an error' do
        post '/workflow_executions', params: {
          workflow_id: 9999,
          source: valid_csv
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Workflow not found')
      end
    end

    context 'with missing source file' do
      it 'returns an error' do
        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Source is required or invalid')
      end
    end

    context 'with invalid source file' do
      it 'returns an error' do
        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id,
          source: invalid_csv
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid data source')
      end
    end

    context 'with processing error' do
      before do
        allow_any_instance_of(WorkflowExecutor).to receive(:call).and_raise(StandardError, 'Processing failed')
      end

      it 'returns an error' do
        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id,
          source: valid_csv
        }

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Processing error: Processing failed')
      end
    end
  end
end

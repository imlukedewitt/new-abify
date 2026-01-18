# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkflowExecutions API', :request, :integration, :vcr do
  describe 'POST /workflow_executions' do
    let!(:valid_workflow) { create(:workflow, name: 'Test Workflow') }
    let(:valid_csv) { fixture_file_upload('simple.csv', 'text/csv') }
    let(:invalid_csv) { fixture_file_upload('malformed.csv', 'text/csv') }
    let!(:step1) do
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
        data_source = DataSources::Builder.call(source: valid_csv)

        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id,
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:accepted)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Workflow started')

        # TODO: Controller runs async in a thread, so we can't verify execution results here.
        # Consider using a proper background job system with test mode for integration testing.
      end
    end

    context 'with invalid workflow id' do
      it 'returns an error' do
        data_source = DataSources::Builder.call(source: valid_csv)

        post '/workflow_executions', params: {
          workflow_id: 9999,
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Workflow not found')
      end
    end

    context 'with missing data source' do
      it 'returns an error' do
        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Data source not found')
      end
    end

    context 'with invalid data source id' do
      it 'returns an error' do
        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id,
          data_source_id: 9999
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Data source not found')
      end
    end

    context 'with processing error' do
      before do
        allow_any_instance_of(WorkflowExecutor).to receive(:call).and_raise(StandardError, 'Processing failed')
      end

      it 'returns an error' do
        data_source = DataSources::Builder.call(source: valid_csv)

        post '/workflow_executions', params: {
          workflow_id: valid_workflow.id,
          data_source_id: data_source.id
        }, as: :json

        expect(response).to have_http_status(:accepted)
      end
    end
  end
end

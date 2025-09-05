# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSourcesController, type: :controller do
  describe 'POST #create' do
    context 'with valid CSV file' do
      let(:csv_file) { fixture_file_upload('spec/fixtures/files/3_rows.csv', 'text/csv') }

      it 'creates a new data source' do
        expect do
          post :create, params: { source: csv_file }
        end.to change(DataSource, :count).by(1)
      end

      it 'returns created status and data_source_id' do
        post :create, params: { source: csv_file }
        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data_source_id')
        expect(json_response['data_source_id']).to be_a(Integer)
      end
    end

    context 'with invalid file type' do
      let(:invalid_file) { fixture_file_upload('spec/fixtures/files/plain_text.txt', 'text/plain') }

      it 'does not create a new data source' do
        expect do
          post :create, params: { source: invalid_file }
        end.not_to change(DataSource, :count)
      end

      it 'returns bad request status' do
        post :create, params: { source: invalid_file }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        post :create, params: { source: invalid_file }
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Invalid data source: Unsupported file type')
      end
    end

    context 'with non-file parameter' do
      it 'returns bad request status' do
        post :create, params: { source: 'not_a_file' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        post :create, params: { source: 'not_a_file' }
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Invalid data source: Source must be a file upload')
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSourcesController, type: :controller do
  describe 'POST #create' do
    context 'with valid CSV file' do
      let(:csv_file) { fixture_file_upload('spec/fixtures/files/3_rows.csv', 'text/csv') }

      it 'creates a new data source' do
        expect do
          post :create, params: { source: csv_file }, as: :json
        end.to change(DataSource, :count).by(1)
      end

      it 'returns created status and data_source_id' do
        post :create, params: { source: csv_file }, as: :json
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
          post :create, params: { source: invalid_file }, as: :json
        end.not_to change(DataSource, :count)
      end

      it 'returns bad request status' do
        post :create, params: { source: invalid_file }, as: :json
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        post :create, params: { source: invalid_file }, as: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Invalid data source: Unsupported file type')
      end
    end

    context 'with non-file parameter' do
      it 'returns bad request status' do
        post :create, params: { source: 'not_a_file' }, as: :json
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message' do
        post :create, params: { source: 'not_a_file' }, as: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('Invalid data source: Source must be a file upload')
      end
    end
  end

  describe 'GET #index' do
    let!(:data_source_1) { create(:data_source) }
    let!(:data_source_2) { create(:data_source) }

    it 'lists the data sources' do
      get :index, as: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      data_sources = json_response['data_sources']
      expect(data_sources).to be_a(Array)
      expect(data_sources.count).to equal(2)
      expect(data_sources.map { |ds| ds['id'] }).to match_array(
        [
          data_source_1.id,
          data_source_2.id
        ]
      )
    end
  end

  describe 'GET #show' do
    let!(:data_source) { create(:data_source) }

    it 'retrieves a data source' do
      get :show, params: { id: data_source.id }, as: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      retrieved_data_source = json_response['data_source']
      expect(retrieved_data_source).to be_a(Hash)
      expect(retrieved_data_source['id']).to eq(data_source.id)
    end

    it 'returns not found when the data source does not exist' do
      get :show, params: { id: -1 }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end

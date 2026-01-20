# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectionsController, type: :controller do
  let(:user) { create(:user) }

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          connection: {
            user_id: user.id,
            name: 'My Salesforce',
            handle: 'salesforce_prod',
            credentials: {
              type: 'bearer',
              token: 'sk-secret-123'
            }
          }
        }
      end

      it 'creates a new connection' do
        expect do
          post :create, params: valid_params, as: :json
        end.to change(Connection, :count).by(1)
      end

      it 'returns the connection id' do
        post :create, params: valid_params, as: :json
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('connection_id')
      end
    end

    context 'with subdomain and domain' do
      let(:params_with_url_fields) do
        {
          connection: {
            user_id: user.id,
            name: 'Salesforce with Domain',
            handle: 'salesforce_custom',
            credentials: { type: 'bearer', token: 'token123' },
            subdomain: 'mycompany',
            domain: 'salesforce.com'
          }
        }
      end

      it 'creates connection with subdomain and domain' do
        post :create, params: params_with_url_fields, as: :json
        expect(response).to have_http_status(:created)

        connection = Connection.last
        expect(connection.subdomain).to eq('mycompany')
        expect(connection.domain).to eq('salesforce.com')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          connection: {
            user_id: user.id,
            name: 'My Connection',
            handle: 'INVALID-HANDLE',
            credentials: { type: 'bearer', token: 'token' }
          }
        }
      end

      it 'returns an error' do
        post :create, params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include(a_string_including('Handle must start with a letter'))
      end
    end

    context 'with missing name' do
      let(:params_without_name) do
        {
          connection: {
            user_id: user.id,
            handle: 'test_handle',
            credentials: { type: 'bearer', token: 'token' }
          }
        }
      end

      it 'returns an error' do
        post :create, params: params_without_name, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include("Name can't be blank")
      end
    end
  end

  describe 'GET #index' do
    let!(:first_connection) { create(:connection, user: user) }
    let!(:second_connection) { create(:connection, user: user) }
    let!(:other_user_connection) { create(:connection, user: create(:user)) }

    it 'returns all connections' do
      get :index, as: :json
      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response).to be_a(Hash)
      expect(json_response[:connections]).to be_an(Array)
      expect(json_response[:connections].count).to eq(3)
    end

    it 'filters by user_id when provided' do
      get :index, params: { user_id: user.id }, as: :json
      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      connections = json_response[:connections]
      expect(connections.count).to eq(2)
      expect(connections.pluck(:id)).to match_array([first_connection.id, second_connection.id])
    end

    it 'does not expose credentials' do
      get :index, as: :json
      json_response = JSON.parse(response.body, symbolize_names: true)

      json_response[:connections].each do |connection|
        expect(connection).not_to have_key(:credentials)
      end
    end
  end

  describe 'GET #show' do
    let!(:connection) { create(:connection, user: user) }

    context 'with a valid connection id' do
      it 'returns the connection' do
        get :show, params: { id: connection.id }, as: :json
        expect(response).to be_successful
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:connection][:id]).to eq(connection.id)
        expect(json_response[:connection][:name]).to eq(connection.name)
      end

      it 'does not expose credentials' do
        get :show, params: { id: connection.id }, as: :json
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:connection]).not_to have_key(:credentials)
      end

      it 'returns subdomain, domain, and base_url when present' do
        connection_with_url = create(:connection,
                                     user: user,
                                     subdomain: 'acme',
                                     domain: 'salesforce.com')

        get :show, params: { id: connection_with_url.id }, as: :json
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:connection][:subdomain]).to eq('acme')
        expect(json_response[:connection][:domain]).to eq('salesforce.com')
        expect(json_response[:connection][:base_url]).to eq('https://acme.salesforce.com')
      end
    end

    context 'with an invalid connection id' do
      it 'returns not found' do
        get :show, params: { id: 99_999 }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:connection) { create(:connection, user: user, name: 'Old Name') }

    context 'with valid parameters' do
      let(:update_params) do
        {
          id: connection.id,
          connection: {
            name: 'Updated Name'
          }
        }
      end

      it 'updates the connection' do
        patch :update, params: update_params, as: :json
        expect(response).to be_successful
        expect(connection.reload.name).to eq('Updated Name')
      end

      it 'updates subdomain and domain' do
        update_params = {
          id: connection.id,
          connection: {
            subdomain: 'newcompany',
            domain: 'my-app.com'
          }
        }

        patch :update, params: update_params, as: :json
        expect(response).to be_successful

        connection.reload
        expect(connection.subdomain).to eq('newcompany')
        expect(connection.domain).to eq('my-app.com')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          id: connection.id,
          connection: {
            handle: 'INVALID-HANDLE'
          }
        }
      end

      it 'returns an error' do
        patch :update, params: invalid_update_params, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
    end

    context 'with invalid connection id' do
      it 'returns not found' do
        patch :update, params: { id: 99_999, connection: { name: 'Test' } }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:connection) { create(:connection, user: user) }

    it 'deletes the connection' do
      expect do
        delete :destroy, params: { id: connection.id }, as: :json
      end.to change(Connection, :count).by(-1)
    end

    it 'returns no content' do
      delete :destroy, params: { id: connection.id }, as: :json
      expect(response).to have_http_status(:no_content)
    end

    context 'with invalid connection id' do
      it 'returns not found' do
        delete :destroy, params: { id: 99_999 }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

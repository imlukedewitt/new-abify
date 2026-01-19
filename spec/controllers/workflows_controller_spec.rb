# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowsController, type: :controller do
  describe 'POST #create' do
    context 'with valid workflow config' do
      let(:valid_config) do
        {
          name: 'Test Workflow',
          config: {
            workflow: {
              liquid_templates: {
                group_by: '{{row.group}}',
                sort_by: '{{row.priority}}'
              },
              connection: {
                subdomain: 'test',
                domain: 'example.com'
              }
            }
          }
        }
      end

      it 'creates a new workflow' do
        expect do
          post :create, params: valid_config, as: :json
        end.to change(Workflow, :count).by(1)
      end
    end

    context 'with a connection_id' do
      let(:user) { create(:user) }
      let(:connection) { create(:connection, user: user) }
      let(:config_with_connection) do
        {
          name: 'Workflow with Connection',
          connection_id: connection.id,
          config: {
            workflow: {
              liquid_templates: {
                group_by: '{{row.group}}'
              }
            }
          }
        }
      end

      it 'creates a workflow with the connection' do
        expect do
          post :create, params: config_with_connection, as: :json
        end.to change(Workflow, :count).by(1)

        workflow = Workflow.last
        expect(workflow.connection_id).to eq(connection.id)
      end
    end

    context 'with nested steps' do
      let(:config_with_steps) do
        {
          name: 'Config with steps',
          steps_attributes: [
            name: 'First step',
            config: {
              liquid_templates: {
                name: 'Step name',
                url: 'api.com',
                method: 'get'
              }
            }
          ]
        }
      end

      it 'creates nested steps' do
        expect { post :create, params: config_with_steps, as: :json }
          .to change(Workflow, :count)
          .by(1).and change(Step, :count).by(1)

        expect(Step.last.name).to eq('First step')
      end
    end

    context 'with invalid workflow config' do
      let(:invalid_config) do
        {
          name: 'Test Workflow',
          config: {
            workflow: {
              invalid_section: {
                some_key: 'some_value'
              }
            }
          }
        }
      end

      it 'returns an error' do
        post :create, params: invalid_config, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include(
          a_string_including('unexpected section in workflow config: invalid_section')
        )
      end
    end

    context 'with missing name parameter' do
      let(:config_without_name) do
        {
          config: {
            workflow: {
              liquid_templates: {
                group_by: '{{row.group}}'
              }
            }
          }
        }
      end

      it 'returns an error' do
        post :create, params: config_without_name, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include("Name can't be blank")
      end
    end
  end

  describe 'GET #index' do
    let!(:workflow_1) { create(:workflow) }
    let!(:workflow_2) { create(:workflow) }

    it 'returns all workflows' do
      get :index, as: :json
      expect(response).to be_successful
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response).to be_a(Hash)
      expect(json_response[:workflows]).to be_an(Array)
      workflows = json_response[:workflows]
      expect(workflows.count).to eq(2)
      expect(workflows.pluck(:id)).to eq([workflow_1.id, workflow_2.id])
    end
  end

  describe 'GET #show' do
    let!(:workflow) { create(:workflow, :with_handle) }
    let(:response) { get :show, params: { id: id }, as: :json }

    context 'with a valid workflow id' do
      let(:id) { workflow.id }
      it 'returns the workflow' do
        expect(response).to be_successful
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:workflow][:id]).to eq(workflow.id)
      end
    end

    context 'with a valid workflow handle' do
      let(:id) { workflow.handle }
      it 'returns the workflow' do
        expect(response).to be_successful
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:workflow][:id]).to eq(workflow.id)
      end
    end

    context 'with an invalid workflow id' do
      let(:id) { 1337 }
      it 'returns an error' do
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(a_string_including("Couldn't find Workflow"))
      end
    end

    context 'with an invalid workflow handle' do
      let(:id) { 'nonexistent-handle' }
      it 'returns an error' do
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(a_string_including("Couldn't find Workflow"))
      end
    end
  end

  describe 'POST #create with handle' do
    it 'creates a workflow with a handle' do
      post :create, params: { name: 'Handled Workflow', handle: 'my-workflow' }, as: :json

      expect(response).to have_http_status(:created)
      workflow = Workflow.last
      expect(workflow.handle).to eq('my-workflow')
    end

    it 'rejects invalid handle format' do
      post :create, params: { name: 'Bad Handle', handle: '123-invalid' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include(a_string_including('must start with a letter'))
    end
  end

  describe 'POST #create with connection_handle' do
    let(:user) { create(:user) }
    let(:connection) { create(:connection, user: user, handle: 'my-connection') }

    it 'creates a workflow using connection_handle' do
      post :create, params: { workflow: { name: 'Connected Workflow', connection_handle: connection.handle } }, as: :json

      expect(response).to have_http_status(:created)
      workflow = Workflow.last
      expect(workflow.connection_id).to eq(connection.id)
    end

    it 'prefers connection_id over connection_handle when both provided' do
      other_connection = create(:connection, user: user, handle: 'other-connection')

      post :create, params: {
        workflow: {
          name: 'Connected Workflow',
          connection_id: connection.id,
          connection_handle: other_connection.handle
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      workflow = Workflow.last
      expect(workflow.connection_id).to eq(connection.id)
    end

    it 'returns error when connection_handle not found' do
      post :create, params: { workflow: { name: 'Workflow', connection_handle: 'nonexistent' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to eq(['Connection not found'])
    end

    it 'returns error when connection_id not found' do
      post :create, params: { workflow: { name: 'Workflow', connection_id: 99_999 } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to eq(['Connection not found'])
    end
  end
end

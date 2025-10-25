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
          post :create, params: valid_config
        end.to change(Workflow, :count).by(1)
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
        post :create, params: invalid_config
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('unexpected section in workflow config: invalid_section')
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
        post :create, params: config_without_name
        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include("Name can't be blank")
      end
    end
  end

  describe 'GET #index' do
    let!(:workflow_1) { create(:workflow) }
    let!(:workflow_2) { create(:workflow) }

    it 'returns all workflows' do
      get :index
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
    let!(:workflow) { create(:workflow) }
    let(:response) { get :show, params: { id: id } }

    context 'with a valid workflow id' do
      let(:id) { workflow.id }
      it 'returns the workflow' do
        expect(response).to be_successful
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response[:workflow][:id]).to eq(workflow.id)
      end
    end

    context "with an invalid workflow id" do
      let(:id) { 1337 }
      it 'returns an error' do
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq(
          {
            "errors" => "Couldn't find Workflow with 'id'=1337"
          }
        )
      end
    end
  end
end

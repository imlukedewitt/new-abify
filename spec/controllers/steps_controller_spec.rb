# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepsController, type: :controller do
  describe 'POST #create' do
    let(:workflow) { create(:workflow) }

    context 'with valid step parameters' do
      let(:valid_params) do
        {
          workflow_id: workflow.id,
          step: {
            name: 'Test Step',
            config: {
              'liquid_templates' => {
                'name' => 'Test Step',
                'url' => '{{base_url}}/api/test',
                'method' => 'get'
              }
            }
          }
        }
      end

      it 'creates a new step' do
        expect do
          post :create, params: valid_params, as: :json
        end.to change(Step, :count).by(1)
      end

      it 'associates the step with the workflow' do
        post :create, params: valid_params, as: :json
        step = Step.last
        expect(step.workflow).to eq(workflow)
      end

      it 'auto-assigns the correct order' do
        post :create, params: valid_params, as: :json
        step = Step.last
        expect(step.order).to eq(1)
      end

      it 'returns created status and step_id' do
        post :create, params: valid_params, as: :json
        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('step_id')
        expect(json_response['step_id']).to be_a(Integer)
      end
    end

    context 'with existing steps' do
      let!(:existing_step) { create(:step, workflow: workflow, order: 3) }

      let(:valid_params) do
        {
          workflow_id: workflow.id,
          step: {
            name: 'New Step',
            config: {
              'liquid_templates' => {
                'name' => 'New Step',
                'url': '{{base_url}}/api/test',
                'method': 'get'
              }
            }
          }
        }
      end

      it 'auto-assigns the next available order' do
        post :create, params: valid_params, as: :json
        step = Step.last
        expect(step.order).to eq(4)
      end
    end

    context 'with invalid step parameters' do
      let(:invalid_params) do
        {
          workflow_id: workflow.id,
          step: {
            name: 'Invalid Step',
            config: {
              'liquid_templates' => {
                'name' => 'Invalid Step'
                # Missing required 'url' key
              }
            }
          }
        }
      end

      it 'does not create a new step' do
        expect do
          post :create, params: invalid_params, as: :json
        end.not_to change(Step, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post :create, params: invalid_params, as: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include('Config step config must include url in liquid_templates')
      end
    end
  end
end

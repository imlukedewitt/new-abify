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
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error messages' do
        post :create, params: invalid_params, as: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include('Config step config must include url in liquid_templates')
      end
    end
  end

  describe 'GET #show' do
    let(:workflow) { create(:workflow) }
    let!(:step) { create(:step, workflow: workflow) }

    context 'with valid step id' do
      it 'returns the step' do
        get :show, params: { workflow_id: workflow.id, id: step.id }
        expect(response).to be_successful
      end
    end

    context 'with invalid step id' do
      it 'returns not found' do
        get :show, params: { workflow_id: workflow.id, id: 99_999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    let(:workflow) { create(:workflow) }
    let!(:step) { create(:step, workflow: workflow, name: 'Original Name') }

    context 'with valid parameters' do
      let(:update_params) do
        {
          workflow_id: workflow.id,
          id: step.id,
          step: {
            name: 'Updated Name',
            config: {
              'liquid_templates' => {
                'url' => '{{base_url}}/api/updated',
                'method' => 'post'
              }
            }
          }
        }
      end

      it 'updates the step' do
        patch :update, params: update_params, as: :json
        expect(response).to be_successful
        expect(step.reload.name).to eq('Updated Name')
      end

      it 'returns the step_id' do
        patch :update, params: update_params, as: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('step_id')
        expect(json_response['step_id']).to eq(step.id)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          workflow_id: workflow.id,
          id: step.id,
          step: {
            name: '',
            config: {
              'liquid_templates' => {
                'url' => nil
              }
            }
          }
        }
      end

      it 'returns unprocessable content' do
        patch :update, params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error messages' do
        patch :update, params: invalid_params, as: :json
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
    end

    context 'with invalid step id' do
      it 'returns not found' do
        patch :update, params: { workflow_id: workflow.id, id: 99_999, step: { name: 'Test' } }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:workflow) { create(:workflow) }
    let!(:step) { create(:step, workflow: workflow) }

    context 'with valid step id' do
      it 'deletes the step' do
        expect do
          delete :destroy, params: { workflow_id: workflow.id, id: step.id }, as: :json
        end.to change(Step, :count).by(-1)
      end

      it 'returns no content' do
        delete :destroy, params: { workflow_id: workflow.id, id: step.id }, as: :json
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with invalid step id' do
      it 'returns not found' do
        delete :destroy, params: { workflow_id: workflow.id, id: 99_999 }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #move_up' do
    let(:workflow) { create(:workflow) }
    let!(:step1) { create(:step, workflow: workflow, order: 1, name: 'First') }
    let!(:step2) { create(:step, workflow: workflow, order: 2, name: 'Second') }
    let!(:step3) { create(:step, workflow: workflow, order: 3, name: 'Third') }

    it 'swaps the step with the previous step' do
      patch :move_up, params: { workflow_id: workflow.id, id: step2.id }
      expect(step1.reload.order).to eq(2)
      expect(step2.reload.order).to eq(1)
    end

    it 'redirects to workflow path' do
      patch :move_up, params: { workflow_id: workflow.id, id: step2.id }
      expect(response).to redirect_to(workflow_path(workflow))
    end

    context 'when step is already first' do
      it 'does not change order' do
        patch :move_up, params: { workflow_id: workflow.id, id: step1.id }
        expect(step1.reload.order).to eq(1)
      end
    end
  end

  describe 'PATCH #move_down' do
    let(:workflow) { create(:workflow) }
    let!(:step1) { create(:step, workflow: workflow, order: 1, name: 'First') }
    let!(:step2) { create(:step, workflow: workflow, order: 2, name: 'Second') }
    let!(:step3) { create(:step, workflow: workflow, order: 3, name: 'Third') }

    it 'swaps the step with the next step' do
      patch :move_down, params: { workflow_id: workflow.id, id: step2.id }
      expect(step2.reload.order).to eq(3)
      expect(step3.reload.order).to eq(2)
    end

    it 'redirects to workflow path' do
      patch :move_down, params: { workflow_id: workflow.id, id: step2.id }
      expect(response).to redirect_to(workflow_path(workflow))
    end

    context 'when step is already last' do
      it 'does not change order' do
        patch :move_down, params: { workflow_id: workflow.id, id: step3.id }
        expect(step3.reload.order).to eq(3)
      end
    end
  end
end

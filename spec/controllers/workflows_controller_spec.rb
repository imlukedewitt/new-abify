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
        expect(response).to have_http_status(:unprocessable_content)
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
        expect(response).to have_http_status(:unprocessable_content)
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

  describe 'PATCH #update' do
    let!(:workflow) { create(:workflow, :with_handle, name: 'Original Name') }

    context 'with valid parameters' do
      it 'updates the workflow' do
        patch :update, params: { id: workflow.id, workflow: { name: 'Updated Name' } }, as: :json
        expect(response).to be_successful
        expect(workflow.reload.name).to eq('Updated Name')
      end

      it 'finds workflow by handle' do
        patch :update, params: { id: workflow.handle, workflow: { name: 'Updated via Handle' } }, as: :json
        expect(response).to be_successful
        expect(workflow.reload.name).to eq('Updated via Handle')
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable content' do
        patch :update, params: { id: workflow.id, workflow: { name: '' } }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error messages' do
        patch :update, params: { id: workflow.id, workflow: { name: '' } }, as: :json
        json = JSON.parse(response.body)
        expect(json).to have_key('errors')
        expect(json['errors']).to include("Name can't be blank")
      end
    end

    context 'with invalid workflow id' do
      it 'returns not found' do
        patch :update, params: { id: 99_999, workflow: { name: 'Test' } }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:workflow) { create(:workflow, :with_handle) }

    context 'with valid workflow id' do
      it 'deletes the workflow' do
        expect do
          delete :destroy, params: { id: workflow.id }, as: :json
        end.to change(Workflow, :count).by(-1)
      end

      it 'returns no content' do
        delete :destroy, params: { id: workflow.id }, as: :json
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with valid workflow handle' do
      it 'deletes the workflow by handle' do
        expect do
          delete :destroy, params: { id: workflow.handle }, as: :json
        end.to change(Workflow, :count).by(-1)
      end
    end

    context 'with associated workflow executions' do
      it 'deletes the workflow and its executions' do
        step = create(:step, workflow: workflow)
        ds = create(:data_source)
        we = create(:workflow_execution, workflow: workflow, data_source: ds)
        row = create(:row, data_source: ds)
        re = create(:row_execution, row: row, workflow_execution: we)
        create(:step_execution, step: step, row: row, row_execution: re)

        expect do
          delete :destroy, params: { id: workflow.id }, as: :json
        end.to change(Workflow, :count).by(-1)
          .and change(WorkflowExecution, :count).by(-1)
          .and change(RowExecution, :count).by(-1)
          .and change(StepExecution, :count).by(-1)
      end
    end

    context 'with invalid workflow id' do
      it 'returns not found' do
        delete :destroy, params: { id: 99_999 }, as: :json
        expect(response).to have_http_status(:not_found)
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

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors']).to include(a_string_including('must start with a letter'))
    end
  end

  describe 'connection_slots' do
    render_views
    describe 'POST #create' do
      it 'creates workflow with connection_slots' do
        post :create, params: {
          workflow: {
            name: 'Workflow with slots',
            connection_slots: [
              { handle: 'target_crm', description: 'Target CRM System', default: true },
              { handle: 'source_db', description: 'Source Database' }
            ]
          }
        }, as: :json

        expect(response).to have_http_status(:created)
        workflow = Workflow.last
        expect(workflow.connection_slots).to eq([
                                                  { 'handle' => 'target_crm', 'description' => 'Target CRM System',
                                                    'default' => true },
                                                  { 'handle' => 'source_db', 'description' => 'Source Database' }
                                                ])
      end

      it 'validates connection_slots format' do
        post :create, params: {
          workflow: {
            name: 'Invalid slots',
            connection_slots: [
              { handle: 'invalid handle', description: 'Test' }
            ]
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(a_string_including('must start with a letter'))
      end

      context 'with HTML format' do
        it 're-renders form with validation errors for invalid connection_slots' do
          post :create, params: {
            workflow: {
              name: 'Invalid slots HTML',
              connection_slots: [
                { handle: 'invalid handle', description: 'Test' }
              ]
            }
          }, as: :html

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).not_to be_empty
          expect(response.body).to match(/must start with a letter/i)
          expect(response.body).to include('Connection Slots')
        end
      end
    end

    describe 'GET #new and #edit' do
      it 'includes connection slots fields in new form' do
        get :new
        expect(response).to be_successful
        expect(response.body).to include('Connection Slots')
        expect(response.body).to include('connection_slots')
      end

      it 'includes connection slots fields in edit form' do
        workflow = create(:workflow)
        get :edit, params: { id: workflow.id }
        expect(response).to be_successful
        expect(response.body).to include('Connection Slots')
        expect(response.body).to include('connection_slots')
      end
    end

    describe 'PATCH #update' do
      let(:workflow) { create(:workflow) }

      it 'updates workflow with connection_slots' do
        patch :update, params: {
          id: workflow.id,
          workflow: {
            connection_slots: [
              { handle: 'new_slot', description: 'New Slot' }
            ]
          }
        }, as: :json

        expect(response).to be_successful
        expect(workflow.reload.connection_slots).to eq([
                                                         { 'handle' => 'new_slot', 'description' => 'New Slot' }
                                                       ])
      end

      it 'clears connection_slots with empty array' do
        workflow.update!(connection_slots: [{ handle: 'old', description: 'old' }])
        patch :update, params: {
          id: workflow.id,
          workflow: {
            connection_slots: []
          }
        }, as: :json

        expect(response).to be_successful
        expect(workflow.reload.connection_slots).to eq([])
      end
    end
  end
end

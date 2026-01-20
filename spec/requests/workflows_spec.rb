# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Workflows', type: :request do
  describe 'GET /workflows' do
    let!(:workflows) { create_list(:workflow, 3) }

    it 'returns a list of workflows' do
      get workflows_path, as: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body, symbolize_names: true)

      expect(json_response[:workflows].count).to eq(3)
      expect(json_response[:workflows].map { |w| w[:id] }).to match_array(workflows.map(&:id))
      expect(json_response[:workflows].map { |w| w[:name] }).to match_array(workflows.map(&:name))
      expect(json_response[:workflows].first).not_to have_key(:steps)
      expect(json_response[:workflows].first).not_to have_key(:config)
    end

    context 'when include_steps is true' do
      let!(:workflows) { create_list(:workflow, 3, :with_steps) }

      it 'includes the steps' do
        get workflows_path(include_steps: true), as: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:workflows].count).to eq(3)
        json_response[:workflows].each do |workflow_json|
          workflow = workflows.find { |w| w.id == workflow_json[:id] }
          expect(workflow_json[:id]).to eq(workflow.id)
          expect(workflow_json[:name]).to eq(workflow.name)
          expect(workflow_json[:steps].count).to eq(workflow.steps.count)

          workflow_json[:steps].each do |step_json|
            step = workflow.steps.find { |s| s.id == step_json[:id] }
            expect(step_json[:id]).to eq(step.id)
            expect(step_json[:name]).to eq(step.name)
            expect(step_json[:order]).to eq(step.order)
          end
        end
      end
    end

    context 'when include_config is true' do
      it 'includes the config' do
        get workflows_path(include_config: true), as: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body, symbolize_names: true)

        expect(json_response[:workflows].count).to eq(3)
        json_response[:workflows].each do |workflow_json|
          workflow = workflows.find { |w| w.id == workflow_json[:id] }
          expect(workflow_json[:id]).to eq(workflow.id)
          expect(workflow_json[:name]).to eq(workflow.name)
          expect(workflow_json[:config]).to eq(workflow.config.deep_symbolize_keys)
        end
      end
    end
  end
end

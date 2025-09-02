# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "WorkflowExecutions", type: :request do
  describe "POST /workflow_executions" do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }

    it "creates a new WorkflowExecution" do
      post "/workflow_executions", params: { workflow_id: workflow.id, data_source_id: data_source.id }
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to have_key("workflow_execution_id")
    end
  end
end

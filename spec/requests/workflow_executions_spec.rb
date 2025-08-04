# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "WorkflowExecutions", type: :request do
  describe "POST /workflow_executions" do
    let(:workflow) { create(:workflow) }
    let(:source) { fixture_file_upload(Rails.root.join('spec/fixtures/files/3_rows.csv'), 'text/csv') }

    it "creates a new WorkflowExecution" do
      post "/workflow_executions", params: { workflow_id: workflow.id, source: source }
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to have_key("workflow_execution_id")
    end
  end
end

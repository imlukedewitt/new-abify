require 'rails_helper'

RSpec.describe 'Viewing Workflow Execution from List', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow) }
  let!(:data_source) { create(:data_source) }

  before do
    sign_in(user)
  end

  it 'navigates from list to execution detail page' do
    execution = create(:workflow_execution, :complete, workflow: workflow, data_source: data_source)
    create_list(:row_execution, 3, :complete, workflow_execution: execution)

    visit workflow_executions_path

    click_link "ID: #{execution.id}"

    expect(page).to have_current_path(%r{/workflow_executions/#{execution.id}})
    expect(page).to have_content("Workflow Execution #{execution.id}")
    expect(page).to have_content(workflow.name)
    expect(page).to have_content('Rows: 3')
    expect(page).to have_content('complete')
    expect(page).to have_css('.collapse', count: 3)
  end
end

require 'rails_helper'

RSpec.describe 'Workflow Execution Row Pagination', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow) }
  let!(:data_source) { create(:data_source) }
  let!(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: data_source) }

  before do
    sign_in(user)
  end

  it 'paginates row executions' do
    create_list(:row_execution, 25, :complete, workflow_execution: workflow_execution)

    visit workflow_execution_path(workflow_execution)

    expect(page).to have_content('Rows: 25')
    expect(page).to have_css('.collapse', count: 20)
    expect(page).to have_css('.join')

    within('.join') { click_link '2' }

    expect(page).to have_css('.collapse', count: 5)
  end
end

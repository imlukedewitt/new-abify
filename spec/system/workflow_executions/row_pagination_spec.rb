require 'rails_helper'

RSpec.describe 'Workflow Execution Row Pagination', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow) }
  let!(:data_source) { create(:data_source) }
  let!(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: data_source) }

  before do
    sign_in(user)
  end

  it 'paginates row executions with correct row indices' do
    rows = create_list(:row, 25, data_source: data_source)
    rows.each { |row| create(:row_execution, :complete, workflow_execution: workflow_execution, row: row) }

    visit workflow_execution_path(workflow_execution)

    expect(page).to have_content('Rows: 25')
    expect(page).to have_css('.collapse', count: 20)
    expect(page).to have_css('.join')

    # Page 1 shows first 20 rows (lowest source_index first)
    titles = page.all('.collapse-title').map(&:text)
    expect(titles.first).to include("Row #{rows.first.source_index}")
    expect(titles.last).to include("Row #{rows[19].source_index}")

    within('.join') { click_link '2' }

    # Page 2 shows remaining 5 rows
    expect(page).to have_css('.collapse', count: 5)
    titles = page.all('.collapse-title').map(&:text)
    expect(titles.first).to include("Row #{rows[20].source_index}")
    expect(titles.last).to include("Row #{rows.last.source_index}")
  end
end

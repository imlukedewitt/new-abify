require 'rails_helper'

RSpec.describe 'Workflow Executions Pagination', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow) }
  let!(:data_source) { create(:data_source) }

  before do
    sign_in(user)
  end

  it 'paginates workflow executions' do
    create_list(:workflow_execution, 25, workflow: workflow, data_source: data_source)

    visit workflow_executions_path

    expect(page).to have_css('tbody tr', count: 20)
    expect(page).to have_css('.join')

    within('.join') do
      click_link '2'
    end

    expect(page).to have_css('tbody tr', count: 5)
  end

  it 'handles many pages with gaps' do
    create_list(:workflow_execution, 250, workflow: workflow, data_source: data_source)

    visit workflow_executions_path

    # Should show limited window (7 buttons max) with gaps
    buttons = page.all('.join button, .join a')
    expect(buttons.count).to eq(7)

    # Should show first page and last page (13)
    expect(page).to have_selector('.join', text: '1')
    expect(page).to have_selector('.join', text: '13')

    # Should show gap
    expect(page).to have_selector('.join button[disabled]', text: '...')

    # Navigate to page 4 (visible in first window)
    within('.join') { click_link '4' }

    # Should show page 4 active
    expect(page).to have_selector('.join button[disabled].btn-active', text: '4')
    expect(page).to have_selector('.join', text: '1')
    expect(page).to have_selector('.join', text: '13')
  end
end

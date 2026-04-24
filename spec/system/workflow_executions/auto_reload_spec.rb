require 'rails_helper'

RSpec.describe 'Workflow Execution Auto Reload', type: :system do
  self.use_transactional_tests = false

  before do
    WorkflowExecution.destroy_all
    RowExecution.destroy_all
    Row.destroy_all
    DataSource.destroy_all
    Workflow.destroy_all
    User.destroy_all

    @user = create(:user)
    @workflow = create(:workflow)
    @data_source = create(:data_source)

    sign_in(@user)
  end

  after do
    WorkflowExecution.destroy_all
    RowExecution.destroy_all
    Row.destroy_all
    DataSource.destroy_all
    Workflow.destroy_all
    User.destroy_all
  end

  it 'reloads frame when execution status changes from processing to complete' do
    execution = create(:workflow_execution, workflow: @workflow, data_source: @data_source, status: 'processing')

    visit workflow_executions_path

    expect(page).to have_css('.badge-warning', text: 'PROCESSING')

    execution.update!(status: 'complete', completed_at: Time.current)

    using_wait_time(6) do
      expect(page).to have_css('.badge-success', text: 'COMPLETE')
    end
    expect(page).to have_no_css('.badge-warning', text: 'PROCESSING')
  end

  it 'stops polling when all executions are complete' do
    execution = create(:workflow_execution, workflow: @workflow, data_source: @data_source, status: 'processing')

    visit workflow_executions_path
    expect(page).to have_css('.badge-warning', text: 'PROCESSING')

    execution.update!(status: 'complete', completed_at: Time.current)

    # Wait for the frame to reload and show complete
    using_wait_time(6) do
      expect(page).to have_css('.badge-success', text: 'COMPLETE')
    end

    # Inject a marker element inside the frame — if polling continues it will be wiped
    marker = "document.querySelector('turbo-frame#workflow_executions')"
    page.execute_script("#{marker}.insertAdjacentHTML('beforeend', '<div id=polling-marker></div>')")
    expect(page).to have_css('#polling-marker')

    # Wait longer than one polling interval
    sleep 4
    expect(page).to have_css('#polling-marker')
  end

  it 'replaces history on pagination so back button skips the list' do
    create_list(:workflow_execution, 25, :complete, workflow: @workflow, data_source: @data_source)

    visit workflows_path
    visit workflow_executions_path

    within('.join') { click_link '2' }

    expect(page).to have_current_path(%r{/workflow_executions\?page=2})

    page.go_back

    # With replace, back skips both page 1 and page 2 of the list
    expect(page).to have_current_path(%r{/workflows$})
  end
end

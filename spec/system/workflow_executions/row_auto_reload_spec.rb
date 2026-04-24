require 'rails_helper'

RSpec.describe 'Row Execution Auto Reload', type: :system do
  self.use_transactional_tests = false

  before do
    RowExecution.destroy_all
    WorkflowExecution.destroy_all
    Row.destroy_all
    DataSource.destroy_all
    Workflow.destroy_all
    User.destroy_all

    @user = create(:user)
    @workflow = create(:workflow)
    @data_source = create(:data_source)
    @workflow_execution = create(:workflow_execution, workflow: @workflow, data_source: @data_source)

    sign_in(@user)
  end

  after do
    RowExecution.destroy_all
    WorkflowExecution.destroy_all
    Row.destroy_all
    DataSource.destroy_all
    Workflow.destroy_all
    User.destroy_all
  end

  it 'reloads frame when row execution status changes from processing to complete' do
    row = create(:row, data_source: @data_source)
    row_execution = create(:row_execution, workflow_execution: @workflow_execution, row: row, status: 'processing')

    visit workflow_execution_path(@workflow_execution)

    expect(page).to have_css('.badge-warning', text: 'processing')

    row_execution.update!(status: 'complete', completed_at: Time.current)

    using_wait_time(6) do
      expect(page).to have_css('.badge-success', text: 'complete')
    end
    expect(page).to have_no_css('.badge-warning', text: 'processing')
  end

  it 'stops polling when all row executions are complete' do
    row = create(:row, data_source: @data_source)
    row_execution = create(:row_execution, workflow_execution: @workflow_execution, row: row, status: 'processing')

    visit workflow_execution_path(@workflow_execution)
    expect(page).to have_css('.badge-warning', text: 'processing')

    # Complete the row execution
    row_execution.update!(status: 'complete', completed_at: Time.current)
    @workflow_execution.update!(status: 'complete', completed_at: Time.current)

    # Wait for the frame to reload and show complete
    using_wait_time(6) do
      expect(page).to have_css('.badge-success', text: 'complete')
    end

    # Inject a marker element inside the frame — if polling continues it will be wiped
    page.execute_script("document.querySelector('turbo-frame#row_executions').insertAdjacentHTML('beforeend', '<div id=polling-marker></div>')")
    expect(page).to have_css('#polling-marker')

    # Wait longer than one polling interval — marker should survive
    sleep 4
    expect(page).to have_css('#polling-marker')
  end
end

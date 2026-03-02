require 'rails_helper'

RSpec.describe 'Workflow Execution Logs', type: :system do
  let!(:user) { create(:user) }
  let!(:connection) { create(:connection, user: user, name: 'Target CRM', credentials: { 'api_key' => 'secret-123' }) }
  let!(:data_source) { create(:data_source, name: 'Sample Leads') }
  let!(:row) { create(:row, data_source: data_source, data: { 'email' => 'test@example.com', 'name' => 'John Doe' }) }

  let!(:workflow) do
    create(:workflow, name: 'Sync Lead to CRM', connection_slots: [
             { 'handle' => 'crm_slot', 'description' => 'Your primary CRM instance' }
           ]).tap do |w|
      create(:step, workflow: w, position: 1, name: 'Create Record', config: {
               'liquid_templates' => {
                 'name' => 'Create CRM Record',
                 'url' => 'https://api.crm.com/leads',
                 'method' => 'post',
                 'connection_slot' => 'crm_slot',
                 'body' => '{"email": "{{row.email}}"}',
                 'success_data' => { 'external_id' => '{{response.id}}' }
               }
             })
    end
  end

  before do
    # Stub HydraManager to simulate successful API response
    allow(HydraManager.instance).to receive(:queue) do |**args|
      response = double('Response', code: 201, body: '{"id": "CRM-999", "status": "created"}')
      args[:on_complete]&.call(response)
    end
    allow(HydraManager.instance).to receive(:run)
  end

  it 'executes a workflow and verifies the detailed logs' do
    # 1. Start Execution
    visit workflows_path

    within 'tr', text: 'Sync Lead to CRM' do
      click_link 'Run'
    end

    expect(page).to have_content('Execute Workflow: Sync Lead to CRM')

    select 'Sample Leads', from: 'Data Source'
    select 'Target CRM', from: 'crm_slot - Your primary CRM instance'
    click_button 'Execute Workflow'

    expect(page).to have_content('Workflow started')

    # 2. Wait for background execution to complete
    execution = WorkflowExecution.last
    max_wait = 50
    while execution.status != 'complete' && max_wait > 0
      sleep 0.1
      execution.reload
      max_wait -= 1
    end
    expect(execution.status).to eq('complete')

    # 3. Visit the Logs Page (Execution Details)
    visit workflow_execution_path(execution)

    expect(page).to have_content("Workflow Execution #{execution.id}")
    expect(page).to have_content('Workflow: Sync Lead to CRM')

    # 4. Confirm Row Details are present
    expect(page).to have_content('Row 1')
    expect(page).to have_content('complete')

    # 5. Expand Row and Verify Step Results
    # DaisyUI/Tailwind collapse usually uses hidden checkboxes or radio buttons
    # We find the input and check it to expand the collapse
    row_collapse = find('.collapse', text: 'Row 1', match: :prefer_exact)
    row_collapse.find('input[type="checkbox"]', visible: :all, match: :first).check

    # Wait for visibility
    expect(page).to have_content('Step 1: Create Record')

    within row_collapse.find('.collapse-content', match: :first) do
      # Expand Step details
      step_collapse = find('.collapse', text: 'Step 1: Create Record')
      step_collapse.find('input[type="checkbox"]', visible: :all, match: :first).check

      within step_collapse.find('.collapse-content') do
        expect(page).to have_content('Result:')
        expect(page).to have_content('"external_id": "CRM-999"')
      end
    end
  end
end

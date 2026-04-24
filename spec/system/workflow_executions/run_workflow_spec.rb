require 'rails_helper'

RSpec.describe 'Run Workflow', type: :system do
  let!(:user) { create(:user) }
  let!(:connection) { create(:connection, user: user, name: 'Main CRM') }
  let!(:data_source) { create(:data_source, name: 'Customer List 2026') }
  let!(:workflow) do
    create(:workflow, name: 'Sync Customers', connection_slots: [
             { 'handle' => 'crm', 'description' => 'Your primary CRM instance' }
           ]).tap do |w|
      create(:step, workflow: w, config: {
               'liquid_templates' => {
                 'name' => 'Sync Step',
                 'url' => 'https://api.example.com/sync',
                 'method' => 'post',
                 'connection_slot' => 'crm'
               }
             })
    end
  end

  before do
    # Stub HydraManager to prevent actual HTTP
    allow(HydraManager.instance).to receive(:queue) do |**args|
      response = double('Response', code: 200, body: '{"success": true}')
      args[:on_complete]&.call(response)
    end
    allow(HydraManager.instance).to receive(:run)
  end

  before do
    sign_in(user)
  end

  it 'allows a user to map connection slots and execute a workflow' do
    visit workflows_path

    # Verify the "Run" button exists (from my recent UI update)
    within 'tr', text: 'Sync Customers' do
      click_link 'Run'
    end

    expect(page).to have_content('Execute Workflow: Sync Customers')
    expect(page).to have_content('Connection Mapping')
    expect(page).to have_content('crm - Your primary CRM instance')

    # Fill the form
    select 'Customer List 2026', from: 'Data Source'
    select 'Main CRM', from: 'crm - Your primary CRM instance'

    click_button 'Execute Workflow'

    # Verify redirection and success message
    expect(page).to have_current_path(workflow_execution_path(WorkflowExecution.last))
    expect(page).to have_content('Workflow started')

    # Verify record creation
    execution = WorkflowExecution.last
    expect(execution.workflow).to eq(workflow)
    expect(execution.data_source).to eq(data_source)
    expect(execution.connection_mappings['crm']['connection_id']).to eq(connection.id.to_s)
    expect(execution.connection_mappings['crm']['connection_name']).to eq('Main CRM')

    # Wait for execution to finish
    max_wait = 50
    while execution.status == 'pending' && max_wait > 0
      sleep 0.1
      execution.reload
      max_wait -= 1
    end

    expect(execution.status).to eq('complete')
  end

  it 'shows validation errors when required mappings are missing' do
    visit workflows_path

    within 'tr', text: 'Sync Customers' do
      click_link 'Run'
    end

    # Leave mapping blank and submit
    select 'Customer List 2026', from: 'Data Source'
    # No mapping selected

    click_button 'Execute Workflow'

    # Verify we stay on the page and see errors
    expect(page).to have_content('Execute Workflow: Sync Customers')
    expect(page).to have_content("Connection mappings Missing mapping for slot 'crm'")
  end
end

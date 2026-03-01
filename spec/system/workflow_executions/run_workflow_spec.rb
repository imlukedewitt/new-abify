require 'rails_helper'

RSpec.describe 'Run Workflow', type: :system do
  let!(:user) { create(:user) }
  let!(:connection) { create(:connection, user: user, name: 'Main CRM') }
  let!(:data_source) { create(:data_source, name: 'Customer List 2026') }
  let!(:workflow) do
    create(:workflow, name: 'Sync Customers', connection_slots: [
             { 'handle' => 'crm', 'description' => 'Your primary CRM instance' }
           ])
  end

  before do
    # Current.user is handled by the developer bypass in Authentication concern
    # because Rails.env.test? is true and no Authorization header is present.
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
    expect(page).to have_current_path(data_source_path(data_source))
    expect(page).to have_content('Workflow started')

    # Verify record creation
    execution = WorkflowExecution.last
    expect(execution.workflow).to eq(workflow)
    expect(execution.data_source).to eq(data_source)
    expect(execution.connection_mappings['crm']['connection_id']).to eq(connection.id.to_s)
    expect(execution.connection_mappings['crm']['connection_name']).to eq('Main CRM')
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

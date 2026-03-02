require 'rails_helper'

RSpec.describe 'Workflow Creation', type: :system do
  let!(:user) { create(:user) }

  before do
    # Authentication bypass will set Current.user = User.last
    # Ensure our user is the last one
    user
  end

  it 'creates a workflow and verifies database persistence' do
    visit workflows_path

    expect(page).to have_content('Workflows')
    click_link 'New Workflow'

    expect(page).to have_current_path(new_workflow_path)
    expect(page).to have_content('New Workflow')

    fill_in 'Name', with: 'My Test Workflow'
    fill_in 'Handle', with: 'my-test-workflow'
    # Connection slots: fill the required slot handle
    fill_in 'Slot Handle', with: 'default-slot'

    click_button 'Create Workflow'

    # Should redirect to show page with success message
    expect(page).to have_current_path(workflow_path(Workflow.last))
    expect(page).to have_content('Workflow created successfully')
    expect(page).to have_content('My Test Workflow')
    expect(page).to have_content('my-test-workflow')

    # Verify database record matches input
    workflow = Workflow.last
    expect(workflow.name).to eq('My Test Workflow')
    expect(workflow.handle).to eq('my-test-workflow')
    # Verify specific connection slot details (F7)
    expect(workflow.connection_slots).to be_present
    expect(workflow.connection_slots.first['handle']).to eq('default-slot')
  end
end

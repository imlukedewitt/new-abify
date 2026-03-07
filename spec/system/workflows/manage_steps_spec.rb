require 'rails_helper'

RSpec.describe 'Step Management', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow, :with_steps) }

  before do
    sign_in(user)
  end

  describe 'adding a step' do
    it 'adds a new step to the workflow' do
      visit workflow_path(workflow)

      expect(page).to have_content('Steps (3)') # initial three steps from factory
      click_link '+ Add Step'

      expect(page).to have_current_path(new_workflow_step_path(workflow))
      expect(page).to have_content('New Step')

      fill_in 'Step Name', with: 'My New Step'
      # F2 fix: label linked to field now
      fill_in 'URL', with: 'https://api.example.com/new'

      click_button 'Create Step'

      # Should redirect to step show page with success message
      expect(page).to have_current_path(workflow_step_path(workflow, Step.last))
      expect(page).to have_content('Step created successfully')
      expect(page).to have_content('My New Step')

      # Return to workflow page and verify step count increased
      visit workflow_path(workflow)
      expect(page).to have_content('Steps (4)')
      expect(page).to have_content('My New Step')
    end
  end

  describe 'reordering steps' do
    it 'moves a step down and updates positions' do
      # Ensure we have at least two steps
      steps = workflow.steps.order(position: :asc).to_a
      expect(steps.size).to be >= 2

      first_step = steps[0]
      second_step = steps[1]

      visit workflow_path(workflow)

      # Find the first step's list item and click "Move Down"
      within 'li', text: first_step.name do
        click_button 'Move down'
      end

      # Wait for page reload (redirect to workflow_path)
      expect(page).to have_current_path(workflow_path(workflow))

      # Verify UI order swapped (F3 - Opt 3)
      expect(page).to have_css(".card:nth-child(1)[data-step-id='#{second_step.id}']")
      expect(page).to have_css(".card:nth-child(2)[data-step-id='#{first_step.id}']")

      # Verify database positions
      first_step.reload
      second_step.reload

      expect(first_step.position).to eq(2)
      expect(second_step.position).to eq(1)

      # Also verify the step names still appear on page
      expect(page).to have_content(first_step.name)
      expect(page).to have_content(second_step.name)
    end

    it 'moves a step up and updates positions' do
      steps = workflow.steps.order(position: :asc).to_a
      expect(steps.size).to be >= 2

      first_step = steps[0]
      second_step = steps[1]

      # First move second step up (swap positions)
      visit workflow_path(workflow)

      within 'li', text: second_step.name do
        click_button 'Move up'
      end

      expect(page).to have_current_path(workflow_path(workflow))

      first_step.reload
      second_step.reload

      expect(first_step.position).to eq(2)
      expect(second_step.position).to eq(1)
    end
  end
end

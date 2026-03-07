require 'rails_helper'

RSpec.describe 'Connection Management', type: :system do
  let!(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'creating a new connection' do
    it 'creates a connection and shows it in the list' do
      visit connections_path

      expect(page).to have_content('Connections')
      click_link 'New Connection'

      expect(page).to have_current_path(new_connection_path)
      expect(page).to have_content('New Connection')

      fill_in 'Name', with: 'My API Connection'
      fill_in 'Handle', with: 'my-api-connection'
      fill_in 'Credentials (JSON)', with: '{"type": "bearer", "token": "secret123"}'

      click_button 'Create Connection'

      # Should redirect to show page
      expect(page).to have_current_path(connection_path(Connection.last))
      expect(page).to have_content('Connection created successfully')
      expect(page).to have_content('My API Connection')
      expect(page).to have_content('my-api-connection')
    end
  end

  describe 'editing an existing connection' do
    let!(:connection) { create(:connection, user: user, name: 'Old Name', handle: 'old-handle') }

    it 'updates the connection name and shows the change on the show page' do
      visit connections_path

      within 'tr', text: 'Old Name' do
        click_link 'Edit'
      end

      expect(page).to have_current_path(edit_connection_path(connection))
      expect(page).to have_content('Edit Connection')

      fill_in 'Name', with: 'Updated Connection Name'
      click_button 'Update Connection'

      # Should redirect to show page with success message
      expect(page).to have_current_path(connection_path(connection))
      expect(page).to have_content('Connection updated successfully')
      expect(page).to have_content('Updated Connection Name')
      expect(page).to have_content('old-handle') # unchanged handle

      # Verify the change persists in the database
      connection.reload
      expect(connection.name).to eq('Updated Connection Name')
    end
  end
end

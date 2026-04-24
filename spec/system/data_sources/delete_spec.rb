# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Data Source Delete', type: :system do
  let!(:user) { create(:user) }
  let!(:data_source) { create(:csv) }

  before do
    sign_in(user)
    data_source.source = fixture_file_upload('spec/fixtures/files/3_rows.csv', 'text/csv')
    data_source.load_data
  end

  it 'deletes a data source from the show page' do
    visit data_source_path(data_source)

    accept_confirm('Delete this data source and all its rows? This cannot be undone.') do
      click_button 'Delete Data Source'
    end

    expect(page).to have_current_path(data_sources_path)
    expect(page).to have_content('Data source deleted.')
    expect(page).not_to have_content(data_source.name)
  end
end

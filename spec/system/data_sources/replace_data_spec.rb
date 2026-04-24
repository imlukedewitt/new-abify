# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Data Source Replace Data', type: :system do
  let!(:user) { create(:user) }
  let!(:data_source) { create(:csv) }

  before do
    sign_in(user)
    data_source.source = fixture_file_upload('spec/fixtures/files/3_rows.csv', 'text/csv')
    data_source.load_data
  end

  it 'replaces data source rows via file upload' do
    visit data_source_path(data_source)

    expect(page).to have_css('tbody tr', count: 3)
    expect(page).to have_content('john.doe@example.com')

    attach_file 'source', Rails.root.join('spec/fixtures/files/simple.csv')
    click_button 'Upload'

    expect(page).to have_content('Data source updated successfully.')
    expect(page).to have_css('tbody tr', count: 2)
    expect(page).to have_content('foo')
    expect(page).not_to have_content('john.doe@example.com')
  end

  it 'updates the data source name to the new filename' do
    visit data_source_path(data_source)

    attach_file 'source', Rails.root.join('spec/fixtures/files/simple.csv')
    click_button 'Upload'

    expect(page).to have_content('simple.csv')
  end
end

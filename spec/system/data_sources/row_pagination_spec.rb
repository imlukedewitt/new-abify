require 'rails_helper'

RSpec.describe 'Data Source Row Pagination', type: :system do
  let!(:user) { create(:user) }
  let!(:data_source) { create(:data_source) }

  before do
    sign_in(user)
  end

  it 'paginates data source rows' do
    create_list(:row, 25, data_source: data_source, data: { 'email' => 'test@example.com' })

    visit data_source_path(data_source)

    expect(page).to have_css('tbody tr', count: 20)
    expect(page).to have_css('.join')

    within('.join') { click_link '2' }

    expect(page).to have_css('tbody tr', count: 5)
  end
end

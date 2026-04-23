require 'rails_helper'

RSpec.describe 'Data Sources Pagination', type: :system do
  let!(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'paginates data sources' do
    create_list(:data_source, 25)

    visit data_sources_path

    expect(page).to have_css('tbody tr', count: 20)
    expect(page).to have_css('.join')

    within('.join') { click_link '2' }

    expect(page).to have_css('tbody tr', count: 5)
  end
end

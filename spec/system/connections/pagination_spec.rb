require 'rails_helper'

RSpec.describe 'Connections Pagination', type: :system do
  let!(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'paginates connections' do
    create_list(:connection, 25, user: user)

    visit connections_path

    expect(page).to have_css('tbody tr', count: 20)
    expect(page).to have_css('.join')

    within('.join') { click_link '2' }

    expect(page).to have_css('tbody tr', count: 5)
  end
end

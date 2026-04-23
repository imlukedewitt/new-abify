require 'rails_helper'

RSpec.describe 'Workflows Pagination', type: :system do
  let!(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'paginates workflows' do
    create_list(:workflow, 25)

    visit workflows_path

    expect(page).to have_css('tbody tr', count: 20)
    expect(page).to have_css('.join')

    within('.join') { click_link '2' }

    expect(page).to have_css('tbody tr', count: 5)
  end
end

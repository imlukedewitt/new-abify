require 'rails_helper'

RSpec.describe 'Workflows', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow, name: 'Flash Sale Campaign') }

  it 'displays the list of workflows' do
    visit workflows_path

    expect(page).to have_content('Workflows')
  end
end

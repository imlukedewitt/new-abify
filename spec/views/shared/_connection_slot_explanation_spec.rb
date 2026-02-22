require 'rails_helper'

RSpec.describe 'shared/_connection_slot_explanation', type: :view do
  it 'renders the tooltip with simplified text' do
    render
    expect(rendered).to match(/tooltip/)
    expect(rendered).to match(/Placeholders for connections/)
    expect(rendered).to match(/Map to actual connections at execution time/)
  end

  it 'renders the help trigger' do
    render
    expect(rendered).to match(/What is this\?/)
  end
end

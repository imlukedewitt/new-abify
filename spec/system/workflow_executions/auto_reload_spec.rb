require 'rails_helper'

RSpec.describe 'Workflow Execution Auto Reload', type: :system do
  let!(:user) { create(:user) }
  let!(:workflow) { create(:workflow) }
  let!(:data_source) { create(:data_source) }

  before do
    sign_in(user)
  end

  it 'enables polling when incomplete executions exist' do
    create(:workflow_execution, workflow: workflow, data_source: data_source, status: 'processing')

    visit workflow_executions_path

    frame = find('turbo-frame#workflow_executions')
    expect(frame['data-controller']).to eq('reload-frame')
    expect(frame['data-reload-frame-active-value']).to eq('true')
    expect(frame['data-reload-frame-interval-value']).to eq('3000')
  end

  it 'disables polling when all executions are complete' do
    create(:workflow_execution, :complete, workflow: workflow, data_source: data_source)

    visit workflow_executions_path

    frame = find('turbo-frame#workflow_executions')
    expect(frame['data-reload-frame-active-value']).to eq('false')
  end

  it 'uses replace action so pagination stays smooth' do
    create_list(:workflow_execution, 25, :complete, workflow: workflow, data_source: data_source)

    visit workflow_executions_path

    frame = find('turbo-frame#workflow_executions')
    expect(frame['data-turbo-action']).to eq('replace')

    within('.join') { click_link '2' }

    expect(page).to have_current_path(%r{/workflow_executions\?page=2})
  end

  it 'accepts custom poll interval' do
    create(:workflow_execution, workflow: workflow, data_source: data_source, status: 'processing')

    visit workflow_executions_path(poll_interval: 500)

    frame = find('turbo-frame#workflow_executions')
    expect(frame['data-reload-frame-interval-value']).to eq('500')
  end
end

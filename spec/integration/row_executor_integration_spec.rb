# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RowExecutor, :integration, :vcr do
  let(:workflow) { create(:workflow) }
  let(:step) do
    create(:step, workflow: workflow, order: 1, config: {
             'liquid_templates' => {
               'name' => 'Get Post',
               'url' => 'https://jsonplaceholder.typicode.com/posts/1',
               'method' => 'get',
               'success_data' => {
                 'id' => '{{response.id}}',
                 'userId' => '{{response.userId}}',
                 'title' => '{{response.title}}'
               }
             }
           })
  end
  let(:row) { create(:row) }

  it 'processes a single step and updates row data', vcr: { cassette_name: 'jsonplaceholder/get_post' } do
    expect(workflow.steps).to include(step)

    processor = described_class.new(row: row, workflow: workflow)
    processor.call

    HydraManager.instance.run

    row.reload
    expect(row.data).to include('id' => '1', 'userId' => '1', 'title' => be_a(String))
  end

  it 'processes multiple steps in sequence', vcr: { cassette_name: 'jsonplaceholder/multiple_steps' } do
    step

    # Create second step that uses data from first step
    create(:step, workflow: workflow, order: 2, config: {
             'liquid_templates' => {
               'name' => 'Get User',
               'url' => 'https://jsonplaceholder.typicode.com/users/{{row.userId}}',
               'method' => 'get',
               'success_data' => {
                 'username' => '{{response.username}}',
                 'email' => '{{response.email}}'
               }
             }
           })

    processor = described_class.new(row: row, workflow: workflow)
    processor.call

    HydraManager.instance.run

    row.reload
    expect(row.data).to include(
      'id' => '1',
      'userId' => '1',
      'title' => be_a(String),
      'username' => 'Bret',
      'email' => 'Sincere@april.biz'
    )
  end

  it 'handles a failed non-required step gracefully', vcr: { cassette_name: 'jsonplaceholder/not_found' } do
    create(:step, workflow: workflow, order: 1, config: {
             'liquid_templates' => {
               'name' => 'Test 404',
               'url' => 'https://jsonplaceholder.typicode.com/nonexistent',
               'method' => 'get',
               'success_data' => {
                 'id' => '{{response.id}}',
                 'title' => '{{response.title}}'
               }
             }
           })
    empty_row = create(:row, data: {})
    processor = described_class.new(row: empty_row, workflow: workflow)
    processor.call

    expect { HydraManager.instance.run }.not_to raise_error

    empty_row.reload
    expect(empty_row.status).not_to eq('failed')

    # Verify row data was not updated (since the step failed)
    expect(empty_row.data).not_to include('id', 'title', 'username', 'email')
  end
end

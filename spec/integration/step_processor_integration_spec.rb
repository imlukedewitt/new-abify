# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepProcessor, :integration, :vcr do
  let(:workflow) { create(:workflow) }
  let(:step) do
    create(:step, workflow: workflow, config: {
             'liquid_templates' => {
               'name' => 'Get Post',
               'url' => 'https://jsonplaceholder.typicode.com/posts/1',
               'method' => 'get'
             }
           })
  end
  let(:row) { create(:row) }

  it 'can make a real HTTP request and process the response', vcr: { cassette_name: 'jsonplaceholder/get_post' } do
    response_data = nil
    callback = ->(response) { response_data = JSON.parse(response.body) }

    processor = described_class.new(step, row, on_complete: callback)
    processor.call

    # Run the hydra queue to actually make the requests
    HydraManager.instance.run

    # Verify we got data back
    expect(response_data).to include(
      'id' => 1,
      'userId' => kind_of(Integer),
      'title' => be_a(String),
      'body' => be_a(String)
    )
  end

  it 'can make a POST request', vcr: { cassette_name: 'jsonplaceholder/create_post' } do
    step.config = {
      'liquid_templates' => {
        'name' => 'Create Post',
        'url' => 'https://jsonplaceholder.typicode.com/posts',
        'method' => 'post',
        'body' => '{"title":"Test Post","body":"This is a test post","userId":1}'
      }
    }

    response_data = nil
    callback = ->(response) { response_data = JSON.parse(response.body) }

    processor = described_class.new(step, row, on_complete: callback)
    processor.call

    HydraManager.instance.run

    expect(response_data).to include(
      'id' => kind_of(Integer),
      'title' => 'Test Post',
      'body' => 'This is a test post',
      'userId' => 1
    )
  end

  it 'handles errors gracefully', vcr: { cassette_name: 'jsonplaceholder/not_found' } do
    step.config = {
      'liquid_templates' => {
        'name' => 'Test 404',
        'url' => 'https://jsonplaceholder.typicode.com/nonexistent',
        'method' => 'get'
      }
    }

    response_status = nil
    callback = ->(response) { response_status = response.code }

    processor = described_class.new(step, row, on_complete: callback)
    processor.call

    HydraManager.instance.run

    expect(response_status).to eq(404)
  end
end

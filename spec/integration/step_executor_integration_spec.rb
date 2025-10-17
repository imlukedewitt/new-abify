# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepExecutor, :integration, :vcr do
  let(:workflow) { create(:workflow) }
  let(:step) do
    create(:step, workflow: workflow, config: {
             'liquid_templates' => {
               'name' => 'Get Post',
               'url' => 'https://jsonplaceholder.typicode.com/posts/1',
               'method' => 'get',
               'success_data' => {
                 'id' => '{{response.id}}',
                 'userId' => '{{response.userId}}',
                 'title' => '{{response.title}}',
                 'body' => '{{response.body}}'
               }
             }
           })
  end
  let(:row) { create(:row) }

  it 'can make a real HTTP request and process the response', vcr: { cassette_name: 'jsonplaceholder/get_post' } do
    result = nil
    callback = ->(response) { result = response }

    processor = described_class.new(step, row, on_complete: callback)
    processor.call

    # Run the hydra queue to actually make the requests
    HydraManager.instance.run

    # Verify success response
    expect(result[:data]).to include(
      'id' => "1",
      'userId' => "1",
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
        'body' => '{"title":"Test Post","body":"This is a test post","userId":1}',
        'success_data' => {
          'id' => '{{response.id}}',
          'title' => '{{response.title}}',
          'body' => '{{response.body}}',
          'userId' => '{{response.userId}}'
        }
      }
    }

    result = nil
    callback = ->(response) { result = response }

    processor = described_class.new(step, row, on_complete: callback)
    processor.call

    HydraManager.instance.run

    # Verify success response
    expect(result[:data]).to include(
      'id' => "101",
      'title' => 'Test Post',
      'body' => 'This is a test post',
      'userId' => "1"
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

    result = nil
    callback = ->(response) { result = response }

    processor = described_class.new(step, row, on_complete: callback)
    processor.call

    HydraManager.instance.run

    # Verify error response
    expect(result).to include(success: false)
    expect(result).to include(error: "Request failed with status 404")
  end
end

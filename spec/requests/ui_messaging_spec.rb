require 'rails_helper'

RSpec.describe 'UI Messaging', type: :request do
  describe 'Workflow form' do
    it 'renders the connection slot explanation tooltip' do
      get new_workflow_path
      expect(response.body).to include('What is this?')
      expect(response.body).to include('Placeholders for connections')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/hydra_manager'

RSpec.describe HydraManager do
  before :each do
    Typhoeus::Expectation.clear
  end

  describe 'singleton behavior' do
    it 'returns the same instance when called multiple times' do
      instance1 = HydraManager.instance
      instance2 = HydraManager.instance

      expect(instance1).to be(instance2)
    end
  end

  describe '#initialize' do
    it 'sets default max_concurrency to 20' do
      manager = HydraManager.instance

      expect(manager.instance_variable_get(:@max_concurrency)).to eq(20)
    end
  end

  describe '#queue' do
    it 'creates and configures a Typhoeus request properly' do
      manager = HydraManager.instance
      body_data = '{"name": "John", "email": "john@example.com"}'

      request = manager.queue(
        url: 'https://api.example.com/users',
        method: :post,
        params: { name: 'John Doe', email: 'john@example.com' },
        body: body_data
      )

      expect(request).to be_a(Typhoeus::Request)
      expect(request.url).to eq('https://api.example.com/users?name=John+Doe&email=john%40example.com')
      expect(request.options[:method]).to eq(:post)
      expect(request.options[:body]).to eq(body_data)
    end

    it 'sets basic auth when auth_config is provided with type :basic' do
      manager = HydraManager.instance
      auth_config = { type: :basic, username: 'testuser', password: 'password123' }

      request = manager.queue(
        url: 'https://api.example.com/users',
        auth_config: auth_config
      )

      expect(request.options[:userpwd]).to eq('testuser:password123')
      expect(request.options[:headers]['Authorization']).to be_nil
    end

    it 'uses basic auth credentials from environment when env_key is provided' do
      manager = HydraManager.instance
      auth_config = { type: :basic, env_key: 'TEST_DB', username: 'default_user', password: 'default_pass' }

      allow(ENV).to receive(:[]).with('AUTH_BASIC_USER_TEST_DB').and_return('env_username')
      allow(ENV).to receive(:[]).with('AUTH_BASIC_PASS_TEST_DB').and_return('env_password')

      request = manager.queue(
        url: 'https://api.example.com/users',
        auth_config: auth_config
      )

      expect(request.options[:userpwd]).to eq('env_username:env_password')
    end

    it 'sets bearer token when auth_config is provided with type :bearer' do
      manager = HydraManager.instance
      auth_config = { type: :bearer, token: 'secrettoken123' }

      request = manager.queue(
        url: 'https://api.example.com/data',
        method: :get,
        auth_config: auth_config
      )

      expect(request.options[:headers]['Authorization']).to eq('Bearer secrettoken123')
      expect(request.options[:userpwd]).to be_nil
    end

    it 'uses bearer token from environment when env_key is provided' do
      manager = HydraManager.instance
      auth_config = { type: :bearer, env_key: 'TEST_API', token: 'fallback_token' }

      allow(ENV).to receive(:[]).with('AUTH_BEARER_TEST_API').and_return('env_token_123')

      request = manager.queue(
        url: 'https://api.example.com/data',
        auth_config: auth_config
      )

      expect(request.options[:headers]['Authorization']).to eq('Bearer env_token_123')
    end

    it 'sets custom api key header when auth_config is provided with type :api_key' do
      manager = HydraManager.instance
      auth_config = { type: :api_key, header_name: 'X-API-KEY', value: 'abc123key' }

      request = manager.queue(
        url: 'https://api.example.com/data',
        auth_config: auth_config
      )

      expect(request.options[:headers]['X-API-KEY']).to eq('abc123key')
      expect(request.options[:userpwd]).to be_nil
    end

    it 'uses api key from environment when env_key is provided' do
      manager = HydraManager.instance
      auth_config = { type: :api_key, header_name: 'X-API-KEY', env_key: 'TEST_SERVICE', value: 'fallback_key' }

      allow(ENV).to receive(:[]).with('AUTH_APIKEY_TEST_SERVICE').and_return('env_api_key_456')

      request = manager.queue(
        url: 'https://api.example.com/data',
        auth_config: auth_config
      )

      expect(request.options[:headers]['X-API-KEY']).to eq('env_api_key_456')
    end

    it 'sets multiple custom headers when auth_config is provided with type :custom' do
      manager = HydraManager.instance
      auth_config = {
        type: :custom,
        headers: {
          'X-Client-ID' => 'client123',
          'X-App-Version' => '1.0.0'
        }
      }

      request = manager.queue(
        url: 'https://api.example.com/data',
        auth_config: auth_config
      )

      expect(request.options[:headers]['X-Client-ID']).to eq('client123')
      expect(request.options[:headers]['X-App-Version']).to eq('1.0.0')
      expect(request.options[:userpwd]).to be_nil
    end

    it 'uses oauth2 token from environment when env_key is provided' do
      manager = HydraManager.instance
      auth_config = { type: :oauth2, env_key: 'OAUTH_SERVICE', token: 'fallback_oauth_token' }

      allow(ENV).to receive(:[]).with('AUTH_OAUTH_OAUTH_SERVICE').and_return('env_oauth_token_789')

      request = manager.queue(
        url: 'https://api.example.com/data',
        auth_config: auth_config
      )

      expect(request.options[:headers]['Authorization']).to eq('Bearer env_oauth_token_789')
    end

    it 'uses defaults when optional parameters not provided' do
      manager = HydraManager.instance

      request = manager.queue(url: 'https://api.example.com/users')

      expect(request.url).to eq('https://api.example.com/users?')
      expect(request.options[:method]).to eq(:get)
      expect(request.options[:userpwd]).to be_nil
      expect(request.on_complete).to be_empty
    end

    it 'manages requests array and hydra queue ordering' do
      manager = HydraManager.instance
      hydra_mock = instance_double(Typhoeus::Hydra)
      allow(manager).to receive(:hydra).and_return(hydra_mock)
      initial_count = manager.instance_variable_get(:@requests).length

      expect(hydra_mock).to receive(:queue)
      request = manager.queue(url: 'https://api.example.com/users')

      requests_array = manager.instance_variable_get(:@requests)
      expect(requests_array.length).to eq(initial_count + 1)
      expect(requests_array.last).to be(request)

      expect(hydra_mock).to receive(:queue_front)
      manager.queue(url: 'https://api.example.com/users', front: true)
    end

    it 'handles on_complete callbacks' do
      manager = HydraManager.instance
      callback_executed = false
      received_response = nil
      mock_response = double('response')

      callback_proc = proc do |response|
        callback_executed = true
        received_response = response
      end

      request = manager.queue(url: 'https://api.example.com/users', on_complete: callback_proc)

      # Simulate the callback being called
      request.on_complete.first.call(mock_response)
      expect(callback_executed).to be true
      expect(received_response).to be(mock_response)
    end
  end

  describe '#run' do
    it 'calls hydra.run and manages running state' do
      manager = HydraManager.instance
      hydra_mock = instance_double(Typhoeus::Hydra)
      allow(manager).to receive(:hydra).and_return(hydra_mock)
      expect(hydra_mock).to receive(:run)

      expect(manager.instance_variable_get(:@running)).to be false
      manager.run
      expect(manager.instance_variable_get(:@running)).to be false
    end

    it 'sets running state to true during execution' do
      manager = HydraManager.instance
      hydra_mock = instance_double(Typhoeus::Hydra)
      allow(manager).to receive(:hydra).and_return(hydra_mock)

      running_during_execution = nil
      allow(hydra_mock).to receive(:run) do
        running_during_execution = manager.instance_variable_get(:@running)
      end

      manager.run
      expect(running_during_execution).to be true
    end
  end
end

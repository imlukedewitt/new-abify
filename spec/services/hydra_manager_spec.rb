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
    it 'creates a Typhoeus request with the given URL' do
      manager = HydraManager.instance

      request = manager.queue(url: 'https://api.example.com/users')

      expect(request).to be_a(Typhoeus::Request)
      expect(request.url).to eq('https://api.example.com/users?')
      expect(request.options[:method]).to eq(:get)
    end

    it 'sets custom HTTP method when specified' do
      manager = HydraManager.instance

      request = manager.queue(url: 'https://api.example.com/users', method: :post)

      expect(request.options[:method]).to eq(:post)
    end

    it 'properly URL encodes params and adds them to the URL' do
      manager = HydraManager.instance

      request = manager.queue(
        url: 'https://api.example.com/users',
        params: { name: 'John Doe', email: 'john@example.com' }
      )

      expect(request.url).to eq('https://api.example.com/users?name=John+Doe&email=john%40example.com')
    end
  end
end

# frozen_string_literal: true

require 'typhoeus'
require 'uri'

# a singleton class to run requests with Typhoeus / Hydra queue
class HydraManager
  include Singleton

  def initialize(max_concurrency: 20)
    @max_concurrency = max_concurrency
    @requests = []
    @running = false
  end

  def queue(url:, method: :get, params: {}, body: nil, front: false, on_complete: nil)
    options = {
      method: method,
      userpwd: 'abc123:x',
      headers: { 'User-Agent' => 'Agent User', 'Content-Type' => 'application/json' }
    }
    options[:body] = body if body
    encoded_params = url_param_string(params)
    request = Typhoeus::Request.new("#{url}?#{encoded_params}", options)
    request.on_complete { |resp| on_complete.call(resp) } if on_complete

    @requests << request
    front ? hydra.queue_front(request) : hydra.queue(request)
    request
  end

  def run
    @running = true
    hydra.run
    @running = false
  end

  private

  def hydra
    @hydra ||= Typhoeus::Hydra.new(max_concurrency: @max_concurrency)
  end

  def url_param_string(param_hash)
    URI.encode_www_form(param_hash)
  end
end

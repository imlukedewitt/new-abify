# frozen_string_literal: true

require 'typhoeus'
require 'uri'

# a singleton class to run requests with Typhoeus / Hydra queue
class HydraManager
  include Singleton

  AUTH_METHODS = {
    basic: :apply_basic_auth,
    bearer: :apply_bearer_auth,
    api_key: :apply_api_key_auth,
    oauth2: :apply_oauth2_auth,
    custom: :apply_custom_auth
  }.freeze

  def initialize(max_concurrency: 20)
    @max_concurrency = max_concurrency
    @requests = []
    @running = false
  end

  def queue(url:, method: :get, params: {}, body: nil, front: false, on_complete: nil, auth_config: nil)
    options = {
      method: method,
      headers: { 'User-Agent' => 'Agent User', 'Content-Type' => 'application/json' }
    }

    apply_auth_config(options, auth_config) if auth_config

    options[:body] = body if body
    encoded_params = url_param_string(params) if params
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

  def apply_auth_config(options, auth_config)
    config = auth_config.transform_keys(&:to_sym) if auth_config.is_a?(Hash)
    return unless config

    auth_type = config[:type]
    auth_type = auth_type.to_sym if auth_type.is_a?(String)

    method_name = AUTH_METHODS[auth_type]
    raise ArgumentError, "Unknown auth type: #{auth_type}" unless method_name

    send(method_name, options, config)
  end

  def apply_basic_auth(options, config)
    options[:userpwd] = "#{config[:username]}:#{config[:password]}"
  end

  def apply_bearer_auth(options, config)
    options[:headers]['Authorization'] = "Bearer #{config[:token]}"
  end

  def apply_api_key_auth(options, config)
    options[:headers][config[:header_name]] = config[:value]
  end

  def apply_oauth2_auth(options, config)
    options[:headers]['Authorization'] = "Bearer #{config[:token]}"
  end

  def apply_custom_auth(options, config)
    return unless config[:headers].is_a?(Hash)

    config[:headers].each do |key, value|
      options[:headers][key] = value
    end
  end
end

# frozen_string_literal: true

require 'typhoeus'
require 'uri'

# A singleton class to run requests with Typhoeus / Hydra queue
# Authentication tokens can be provided via environment variables:
# - AUTH_BASIC_USER_[ENV_KEY] - For basic auth username
# - AUTH_BASIC_PASS_[ENV_KEY] - For basic auth password
# - AUTH_BEARER_[ENV_KEY] - For bearer token authentication
# - AUTH_APIKEY_[ENV_KEY] - For API key authentication
# - AUTH_OAUTH_[ENV_KEY] - For OAuth2 token authentication
#
# Where [ENV_KEY] is a value provided in the auth_config hash
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
      headers: { 'User-Agent' => 'ABify by Luke', 'Content-Type' => 'application/json' }
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
    Rails.logger.info "Starting Hydra queue"
    @running = true
    hydra.run
    @running = false
    Rails.logger.info "Hydra queue complete"
  end

  private

  def hydra
    @hydra ||= Typhoeus::Hydra.new(max_concurrency: @max_concurrency)
  end

  def url_param_string(param_hash)
    URI.encode_www_form(param_hash)
  end

  def apply_auth_config(options, auth_config)
    config = normalize_auth_config(auth_config)
    return unless config

    auth_type = config[:type].to_sym
    method_name = AUTH_METHODS[auth_type]
    raise ArgumentError, "Unknown auth type: #{auth_type}" unless method_name

    send(method_name, options, config)
  end

  def normalize_auth_config(auth_config)
    return unless auth_config.is_a?(Hash)

    config = auth_config.transform_keys(&:to_sym)
    return unless config[:type].present?

    config[:type] = config[:type].to_sym if config[:type].is_a?(String)
    config
  end

  def apply_basic_auth(options, config)
    username = ENV["AUTH_BASIC_USER_#{config[:env_key]}"] || config[:username]
    password = ENV["AUTH_BASIC_PASS_#{config[:env_key]}"] || config[:password]
    options[:userpwd] = "#{username}:#{password}"
  end

  def apply_bearer_auth(options, config)
    token = ENV["AUTH_BEARER_#{config[:env_key]}"] || config[:token]
    options[:headers]['Authorization'] = "Bearer #{token}"
  end

  def apply_api_key_auth(options, config)
    api_key = ENV["AUTH_APIKEY_#{config[:env_key]}"] || config[:value]
    options[:headers][config[:header_name]] = api_key
  end

  def apply_oauth2_auth(options, config)
    token = ENV["AUTH_OAUTH_#{config[:env_key]}"] || config[:token]
    options[:headers]['Authorization'] = "Bearer #{token}"
  end

  def apply_custom_auth(options, config)
    return unless config[:headers].is_a?(Hash)

    config[:headers].each do |key, value|
      options[:headers][key] = value
    end
  end
end

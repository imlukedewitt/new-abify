# frozen_string_literal: true

module AuthHelper
  def auth_headers(user = nil)
    user ||= create(:user)
    { 'Authorization' => "Bearer #{user.api_token}" }
  end

  def set_auth_header(user = nil)
    user ||= create(:user)
    request.headers['Authorization'] = "Bearer #{user.api_token}"
    user
  end
end

module RequestAuthHelper
  %i[get post put patch delete].each do |method|
    define_method(method) do |path, **args|
      # Merge auth headers into the request unless explicitly provided
      args[:headers] ||= {}
      args[:headers] = auth_headers.merge(args[:headers]) unless args[:headers].key?('Authorization')
      super(path, **args)
    end
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :controller
  config.include AuthHelper, type: :request
  config.include RequestAuthHelper, type: :request

  # Automatically set auth headers for all controller specs
  config.before(:each, type: :controller) do
    set_auth_header
  end
end

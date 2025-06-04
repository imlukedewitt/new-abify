# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.configure_rspec_metadata!

  # Configure VCR to work with Typhoeus
  config.allow_http_connections_when_no_cassette = true

  # Default record mode
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri body]
  }

  # Enable debug logging to see what VCR is doing
  config.debug_logger = $stderr
end

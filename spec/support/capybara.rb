require 'capybara/cuprite'

# Usually, especially when using Selenium, developers tend to increase the max wait time.

# With Cuprite, there is no need for that.
# We use a Capybara default value here explicitly.
Capybara.default_max_wait_time = 2

# Normalize whitespaces when using `has_text?` and similar matchers,
# i.e., ignore newlines, trailing spaces, etc.
# That makes tests less dependent on slightly UI changes.
Capybara.default_normalize_ws = true

Capybara.default_driver = Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  config.prepend_before(:each, type: :system) do
    # Use JS driver always
    driven_by Capybara.javascript_driver, options: {
      window_size: [1200, 800],
      browser_options: {},
      process_timeout: 10,
      inspector: true,
      headless: !ENV['HEADLESS'].in?(%w[n 0 no false]),
      url_blacklist: []
    }
  end
end

require "capybara/rspec"

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]
  end
end

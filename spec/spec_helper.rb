require 'rubygems'
require 'bundler'

ENV['APP_NAME'] = 'Alice'

Bundler.require(:default, :development, :test)

require 'tiki_torch'

require 'support/helpers'
require 'support/consumers'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:each, :integration => true) do
    $messages = TestingHelpers::Messages.new
    setup_torch
  end
  config.after(:each, :integration => true) do
    take_down_torch
  end
end
require 'stubby'
require 'rspec'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    FileUtils.mkdir_p File.expand_path('.test')
  end

  config.after(:each) do
    FileUtils.rm_r File.expand_path('.test')
  end
end

# FIXME: We should modify the load path here.
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'mongoid'
require 'trackoid'
require 'database_cleaner'
require 'rspec'
require 'rspec/autorun'

RSpec.configure do |config|
  config.before(:suite) do
  	Mongoid.load!(File.expand_path(File.dirname(__FILE__) + "/../config/mongoid.yml"), :test)
    DatabaseCleaner[:mongoid].strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
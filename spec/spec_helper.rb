# FIXME: We should modify the load path here.
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'mongoid'
require 'trackoid'
require 'rspec'
require 'rspec/autorun'

RSpec.configure do |config|
  config.before(:suite) do
  	Mongoid.load!(File.expand_path(File.dirname(__FILE__) + "/../config/mongoid.yml"), :test)
  end

  config.after(:each) do
    Mongoid::Config.purge!
  end
end

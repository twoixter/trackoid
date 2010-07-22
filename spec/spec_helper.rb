$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'

gem 'mocha', '>= 0.9.8'

require 'mocha'
require 'mongoid'
require 'trackoid'
require 'spec'
require 'spec/autorun'

Mongoid.configure do |config|
  name = "trackoid_test"
  host = "localhost"
  port = "27017"
#  config.master = Mongo::Connection.new(host, port, :logger => Logger.new(STDOUT)).db(name)
  config.master = Mongo::Connection.new.db(name)
  config.use_object_ids = true
end

Spec::Runner.configure do |config|
  config.mock_with :mocha
  config.before :suite do
    Mongoid.master.collections.reject { |c| c.name =~ /^system\./ }.each(&:drop)
  end
end

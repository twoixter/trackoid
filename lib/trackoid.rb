require 'rubygems'

gem "mongoid", ">= 1.9.0"

require 'trackoid/errors'
require 'trackoid/core_ext'
require 'trackoid/readers'
require 'trackoid/tracker'
require 'trackoid/aggregates'
require 'trackoid/tracker_aggregates'
require 'trackoid/tracking'

module Mongoid #:nodoc:
  module Tracking

    VERSION = File.read(File.expand_path("../VERSION", File.dirname(__FILE__)))

  end
end


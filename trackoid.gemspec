# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require "trackoid/version"

Gem::Specification.new do |s|
  s.name = "trackoid"
  s.description = "Trackoid uses an embeddable approach to track analytics data using the poweful features of MongoDB for scalability"  
  s.summary = "Trackoid is an easy scalable analytics tracker using MongoDB and Mongoid"
  s.version = Trackoid::VERSION
  s.authors = ["Jose Miguel Perez"]
  s.date = "2012-07-07"
  s.email = "josemiguel@perezruiz.com"
  s.homepage = "http://github.com/twoixter/trackoid"
  s.require_paths = ["lib"]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "LICENSE",
    "Rakefile",
    "VERSION",
    "lib/trackoid.rb",
    "lib/trackoid/aggregates.rb",
    "lib/trackoid/core_ext.rb",
    "lib/trackoid/core_ext/range.rb",
    "lib/trackoid/core_ext/time.rb",
    "lib/trackoid/errors.rb",
    "lib/trackoid/reader_extender.rb",
    "lib/trackoid/readers.rb",
    "lib/trackoid/tracker.rb",
    "lib/trackoid/tracker_aggregates.rb",
    "lib/trackoid/tracking.rb",
    "spec/aggregates_spec.rb",
    "spec/ext/range_spec.rb",
    "spec/ext/time_spec.rb",
    "spec/reader_extender_spec.rb",
    "spec/readers_spec.rb",
    "spec/spec.opts",
    "spec/spec_helper.rb",
    "spec/timezone_spec.rb",
    "spec/trackoid_spec.rb",
    "trackoid.gemspec"
  ]

  s.add_dependency 'mongoid', '~> 3.0.5'
  s.add_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'database_cleaner'
end


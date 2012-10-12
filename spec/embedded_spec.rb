#
# This is a simple spec to check if tracking works within embedded documents
# If this passes, the rest of the funcionality it's assumed to work (TZ, etc)
#
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class TestEmbedOne
  include Mongoid::Document
  field :name   # Dummy field
  embeds_one  :embedded_test
end

class TestEmbedMany
  include Mongoid::Document
  field :name   # Dummy field
  embeds_many  :embedded_test
end

class EmbeddedTest
  include Mongoid::Document
  include Mongoid::Tracking
  field :name   # Dummy field
  track :visits
  embedded_in :test_embed_one
  embedded_in :test_embed_many
end

# And Now For Something Completely Different...

class TestEmbedOuter
  include Mongoid::Document
  field :name   # Dummy field
  embeds_one  :test_embed_middle
end

class TestEmbedMiddle
  include Mongoid::Document
  field :name   # Dummy field
  embedded_in :test_embed_outer
  embeds_one  :test_embed_final
end

class TestEmbedFinal
  include Mongoid::Document
  include Mongoid::Tracking
  field :name   # Dummy field
  track :visits
  embedded_in :test_embed_middle
end


describe Mongoid::Tracking do

  # Useful to see all MongoDB operations in place while RSpec is working
  before(:all) do
    # Moped.logger.level = Logger::DEBUG
  end

  context "within a document which embeds one or more models with tracking" do
    let(:today)     { Time.now }
    let(:mock_one)  { TestEmbedOne.create(:name => "Parent", :embedded_test => {:name => "Child"}) }
    let(:mock_many) { TestEmbedMany.create(:name => "Parent", :embedded_test => [{:name => "Child1"}, {:name => "Child2"} ]) }

    it "should have the tracking field working and not bleed to the parent" do
      mock_one.respond_to?(:visits).should be_false
      mock_one.embedded_test.respond_to?(:visits).should be_true

      mock_many.respond_to?(:visits).should be_false
      mock_many.embedded_test.first.respond_to?(:visits).should be_true
      mock_many.embedded_test.last.respond_to?(:visits).should be_true
    end

    it "the tracking data should work fine" do
      mock_one.embedded_test.visits.inc(today)
      mock_one.embedded_test.visits.on(today).should == 1

      mock_many.embedded_test.first.visits.inc(today)
      mock_many.embedded_test.first.visits.on(today).should == 1
      mock_many.embedded_test.last.visits.on(today).should == 0
    end
  end

  context "within a three level embedded model" do
    let(:today) { Time.now }
    let(:outer) { TestEmbedOuter.create(:name => "Outer", :test_embed_middle => {:name => "Middle", :test_embed_final => { :name => "Final" }}) }

    it "should just work..." do
      outer.respond_to?(:visits).should be_false
      outer.test_embed_middle.respond_to?(:visits).should be_false
      outer.test_embed_middle.test_embed_final.respond_to?(:visits).should be_true

      outer.test_embed_middle.test_embed_final.visits.inc(today)
      outer.test_embed_middle.test_embed_final.visits.on(today).should == 1
      outer.test_embed_middle.test_embed_final.visits.on(today - 1.day).should == 0
    end
  end
end

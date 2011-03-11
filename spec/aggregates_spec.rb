require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class TestModel
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field

  # Note that references to "track" and "aggregate" in this test are mixed
  # for testing pourposes. Trackoid does not make any difference in the
  # declaration order of tracking fields and aggregate tokens.
  track :visits
  aggregate :browsers do |b| b.split.first.downcase if b; end

  track :uniques
  aggregate :referers do |r| r.split.last.downcase if r; end
end

class SecondTestModel
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field
  track :something

  aggregate :aggregate_one do 1 end
  aggregate :aggregate_two do "p" end
  aggregate :aggregate_three do BSON::ObjectId("4c4121857bc3cd0d78cb65b2") end
  aggregate :aggregate_four do Time.now end
end

describe Mongoid::Tracking::Aggregates do

  before(:all) do
    @mock = TestModel.new(:name => "TestInstance")
  end

  it "should define a class model named after the original model" do
    defined?(TestModelAggregates).should_not be_nil
  end

  it "should define a class model named after the original second model" do
    defined?(SecondTestModelAggregates).should_not be_nil
  end

  it "should create a has_many relationship in the original model" do
    # Note that due to ActiveSupport "class_inheritable_accessor" this method
    # is available both as class method and instance method.
    @mock.class.method_defined?(:browsers_accessor).should be_true
  end

  it "should have the aggregates klass in a class/instance var" do
    # Note that due to ActiveSupport "class_inheritable_accessor" this method
    # is available both as class method and instance method.
    @mock.class.aggregate_klass == TestModelAggregates
  end

  it "should create a hash in the class with all aggregate fields" do
    # Note that due to ActiveSupport "class_inheritable_accessor" this method
    # is available both as class method and instance method.
    @mock.class.aggregate_fields.keys.to_set.should == [ :browsers, :referers ].to_set
  end

  it "should create an array in the class with all aggregate fields even when monkey patching" do
    class TestModel
      aggregate :quarters do |q|
        "Q1";
      end
    end
    @mock.class.aggregate_fields.keys.to_set.should == [ :browsers, :referers, :quarters ].to_set
  end

  it "the aggregated class should have the same tracking fields as the parent class" do
    TestModelAggregates.tracked_fields.should == TestModel.tracked_fields
  end

  it "should raise error if we try to add an aggregation token twice" do
    lambda {
      class TestModel
        aggregate :referers do
          "(none)"
        end
      end
    }.should raise_error Mongoid::Errors::AggregationAlreadyDefined
  end

  it "should have Mongoid accessors defined" do
    tm = TestModel.create(:name => "Dummy")
    tm.send(tm.class.send(:internal_accessor_name, "browsers")).class.should == Mongoid::Criteria
    tm.send(tm.class.send(:internal_accessor_name, "referers")).class.should == Mongoid::Criteria
    tm.send(tm.class.send(:internal_accessor_name, "quarters")).class.should == Mongoid::Criteria
  end

  it "should indicate this is an aggregated traking object with aggregated?" do
    @mock.aggregated?.should be_true
  end

  it "should indicate this is an aggregated class with aggregated?" do
    @mock.class.aggregated?.should be_true
  end

  it "should raise error if already defined class with the same aggregated klass name" do
    lambda {
      class MockTestAggregates
        def dummy; true; end
      end
      class MockTest
        include Mongoid::Document
        include Mongoid::Tracking
        track :something
        aggregate :other_something do
          "other"
        end
      end
    }.should raise_error Mongoid::Errors::ClassAlreadyDefined
  end

  it "should NOT raise error if the already defined class is our aggregated model" do
    lambda {
      class MockTest2
        include Mongoid::Document
        include Mongoid::Tracking
        track :something
      end
      class MockTest2
        include Mongoid::Document
        include Mongoid::Tracking
        track :something_else
        aggregate :other_something do
          "other"
        end
      end
    }.should_not raise_error Mongoid::Errors::ClassAlreadyDefined
  end

  it "should raise error although the already defined class includes tracking" do
    lambda {
      class MockTest3Aggregates
        include Mongoid::Document
        include Mongoid::Tracking
        track :something
      end
      class MockTest3
        include Mongoid::Document
        include Mongoid::Tracking
        track :something_else
        aggregate :other_something do
          "other"
        end
      end
    }.should raise_error Mongoid::Errors::ClassAlreadyDefined
  end

  describe "testing different object class for aggregation key" do
    before do
      SecondTestModel.all.map(&:destroy)
      SecondTestModel.create(:name => "test")
      @object_id = SecondTestModel.first.id
      @mock = SecondTestModel.find(@object_id)
    end
    
    it "should correctly save all aggregation keys as strings (inc)" do
      @mock.something("test").inc
      @mock.something.aggregate_one.first.key.is_a?(String).should be_true
      @mock.something.aggregate_two.first.key.is_a?(String).should be_true
      @mock.something.aggregate_three.first.key.is_a?(String).should be_true
      @mock.something.aggregate_four.first.key.is_a?(String).should be_true
    end

    it "should correctly save all aggregation keys as strings (set)" do
      @mock.something("test").set(5)
      @mock.something.aggregate_one.first.key.is_a?(String).should be_true
      @mock.something.aggregate_two.first.key.is_a?(String).should be_true
      @mock.something.aggregate_three.first.key.is_a?(String).should be_true
      @mock.something.aggregate_four.first.key.is_a?(String).should be_true
    end

  end

  describe "when tracking a model with aggregation data" do
    before(:all) do
      TestModel.all.map(&:destroy)
      TestModel.create(:name => "test")
      @object_id = TestModel.first.id
    end

    before do
      @mock = TestModel.find(@object_id)
    end

    it "calling an aggregation scope should return the appropiate class" do
      @mock.browsers.class.should == Mongoid::Tracking::TrackerAggregates
    end

    it "should increment visits for all aggregated instances" do
      @mock.visits("Mozilla Firefox").inc
      @mock.browsers.count.should == 1
      @mock.referers.count.should == 1
      @mock.quarters.count.should == 1
    end

    it "should increment visits for specific aggregation keys" do
      @mock.browsers("mozilla").size.should == 1
      @mock.referers("firefox").size.should == 1
      @mock.quarters("Q1").size.should == 1
    end

    it "should NOT increment visits for different aggregation keys" do
      @mock.browsers("internet explorer").size.should == 0
      @mock.referers("yahoo slurp").size.should == 0
      @mock.quarters("Q2").size.should == 0
    end

    it "should have 1 visits today" do
      @mock.visits.browsers.today.should == [["mozilla", 1]]
      @mock.visits.referers.today.should == [["firefox", 1]]
    end

    it "should have 0 visits yesterday" do
      @mock.visits.browsers.yesterday.should == [["mozilla", 0]]
      @mock.visits.referers.yesterday.should == [["firefox", 0]]
    end

    it "should have 1 visits last 7 days" do
      @mock.visits.browsers.last_days(7).should == [["mozilla", [0, 0, 0, 0, 0, 0, 1]]]
      @mock.visits.referers.last_days(7).should == [["firefox", [0, 0, 0, 0, 0, 0, 1]]]
    end

    it "should work also for arbitrary days" do
      @mock.visits.browsers.last_days(15).should == [["mozilla", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]]]
      @mock.visits.referers.last_days(15).should == [["firefox", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]]]
    end

    it "should work adding 1 visit with different aggregation data" do
      @mock.visits("Google Chrome").inc
      @mock.visits.browsers.today.should == [["mozilla", 1], ["google", 1]]
      @mock.visits.referers.today.should == [["firefox", 1], ["chrome", 1]]
      
      # Just for testing array manipulations
      @mock.visits.browsers.today.inject(0) {|total, c| total + c.last }.should == 2
    end

    it "should return only values when specifying the aggregation key" do
      @mock.visits.browsers("mozilla").today.should == 1
    end

    it "should work also with set" do
      @mock.visits("Google Chrome").set(5)
      @mock.visits.browsers.today.should == [["mozilla", 1], ["google", 5]]
      @mock.visits.referers.today.should == [["firefox", 1], ["chrome", 5]]
      @mock.visits.today.should == 5
    end

    it "let's check what happens when sorting the best browser..." do
      @mock.visits("Google Chrome").inc
      @mock.visits.browsers.today.should == [["mozilla", 1], ["google", 6]]
      @mock.visits.browsers.today.max {|a,b| a.second <=> b.second }.should == ["google", 6]
    end

    it "should work without aggregation information" do
      @mock.visits.inc
      @mock.visits.browsers.today.should == [["mozilla", 1], ["google", 6]]
      @mock.visits.referers.today.should == [["firefox", 1], ["chrome", 6]]
      
      # A more throughout test would check totals...
      visits_today = @mock.visits.today
      visits_today_with_browser = @mock.visits.browsers.today.inject(0) {|total, c| total + c.last }
      visits_today.should == visits_today_with_browser
    end
  end

  describe "Testing all accessors" do
    before do
      TestModel.all.map(&:destroy)
      TestModel.create(:name => "test")
      @object_id = TestModel.first.id
      @mock = TestModel.first

      # For 'first' values
      @mock.visits("Mozilla Firefox").set(1, "2010-07-11")
      @mock.visits("Google Chrome").set(2, "2010-07-12")
      @mock.visits("Internet Explorer").set(3, "2010-07-13")
      
      # For 'last' values
      @mock.visits("Mozilla Firefox").set(4, "2010-07-14")
      @mock.visits("Google Chrome").set(5, "2010-07-15")
      @mock.visits("Internet Explorer").set(6, "2010-07-16")
    end

    it "should return the correct values for .all_values" do
      @mock.visits.all_values.should == [1, 2, 3, 4, 5, 6]
    end
    
    it "should return the all values for every aggregate" do
      @mock.visits.browsers.all_values.should == [
        ["mozilla",  [1, 0, 0, 4]],
        ["google",   [2, 0, 0, 5]],
        ["internet", [3, 0, 0, 6]]
      ]
    end
    
    it "should return the correct first_date for every aggregate" do
      @mock.visits.browsers.first_date.should == [
        ["mozilla",  Date.parse("2010-07-11")],
        ["google",   Date.parse("2010-07-12")],
        ["internet", Date.parse("2010-07-13")]
      ]
    end

    it "should return the correct last_date for every aggregate" do
      @mock.visits.browsers.last_date.should == [
        ["mozilla",  Date.parse("2010-07-14")],
        ["google",   Date.parse("2010-07-15")],
        ["internet", Date.parse("2010-07-16")]
      ]
    end

    it "should return the first value for aggregates" do
      @mock.visits.browsers.first_value.should == [
        ["mozilla",  1],
        ["google",   2],
        ["internet", 3]
      ]
    end

    it "should return the last value for aggregates" do
      @mock.visits.browsers.last_value.should == [
        ["mozilla",  4],
        ["google",   5],
        ["internet", 6]
      ]
    end
    
  end
end

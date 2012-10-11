require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class TestModel
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field

  # Note that references to "track" and "aggregate" in this test are mixed
  # for testing purposes. Trackoid does not make any difference in the
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
  aggregate :aggregate_three do Moped::BSON::ObjectId.new end
  aggregate :aggregate_four do Time.now end
end

# Namespaced models to test avoid name collisions
# Collitions may happen when declaring internal aggregate classes for a model
# which has the same name as other models in another namespace
module MyCompany
  class TestPerson
    include Mongoid::Document
    include Mongoid::Tracking

    field :my_name

    track :logins
    aggregate :initials do |n| n.to_s[0]; end
  end
end

module YourCompany
  class TestPerson
    include Mongoid::Document
    include Mongoid::Tracking

    field :your_name

    track :logins
    aggregate :initials do |n| n.to_s[0]; end
  end
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
    }.should raise_error Mongoid::Tracking::Errors::AggregationAlreadyDefined
  end

  it "should raise error if we try to use 'hours' as aggregate" do
    lambda {
      class TestModel
        aggregate :hours do
          "(none)"
        end
      end
    }.should raise_error Mongoid::Tracking::Errors::AggregationNameDeprecated
  end

  it "should have Mongoid accessors defined" do
    tm = TestModel.create(:name => "Dummy")
    tm.send(tm.class.send(:internal_accessor_name, "browsers")).class.should == Mongoid::Relations::Targets::Enumerable
    tm.send(tm.class.send(:internal_accessor_name, "referers")).class.should == Mongoid::Relations::Targets::Enumerable
    tm.send(tm.class.send(:internal_accessor_name, "quarters")).class.should == Mongoid::Relations::Targets::Enumerable
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
    }.should raise_error Mongoid::Tracking::Errors::ClassAlreadyDefined
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
    }.should_not raise_error Mongoid::Tracking::Errors::ClassAlreadyDefined
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
    }.should raise_error Mongoid::Tracking::Errors::ClassAlreadyDefined
  end

  describe "testing different object class for aggregation key" do
    let(:second_test_model) do
      SecondTestModel.create(name: "test")
    end

    it "should correctly save all aggregation keys as strings (inc)" do
      second_test_model.something("test").inc
      second_test_model.something.aggregate_one.first.key.is_a?(String).should be_true
      second_test_model.something.aggregate_two.first.key.is_a?(String).should be_true
      second_test_model.something.aggregate_three.first.key.is_a?(String).should be_true
      second_test_model.something.aggregate_four.first.key.is_a?(String).should be_true
    end

    it "should correctly save all aggregation keys as strings (set)" do
      second_test_model.something("test").set(5)
      second_test_model.something.aggregate_one.first.key.is_a?(String).should be_true
      second_test_model.something.aggregate_two.first.key.is_a?(String).should be_true
      second_test_model.something.aggregate_three.first.key.is_a?(String).should be_true
      second_test_model.something.aggregate_four.first.key.is_a?(String).should be_true
    end
  end

  describe "when tracking a model with aggregation data" do
    let(:test_model) do
      TestModel.create(:name => "test")
    end

    it "calling an aggregation scope should return the appropiate class" do
      test_model.browsers.class.should == Mongoid::Tracking::TrackerAggregates
    end

    it "should increment visits for all aggregated instances" do
      test_model.visits("Mozilla Firefox").inc
      test_model.browsers.count.should == 1
      test_model.referers.count.should == 1
      test_model.quarters.count.should == 1
    end

    it "should increment visits for specific aggregation keys" do
      test_model.visits("Mozilla Firefox").inc
      test_model.browsers("mozilla").size.should == 1
      test_model.referers("firefox").size.should == 1
      test_model.quarters("Q1").size.should == 1
    end

    it "should NOT increment visits for different aggregation keys" do
      test_model.browsers("internet explorer").size.should == 0
      test_model.referers("yahoo slurp").size.should == 0
      test_model.quarters("Q2").size.should == 0
    end

    it "should have 1 visits today" do
      test_model.visits("Mozilla Firefox").inc
      test_model.visits.browsers.today.should == [["mozilla", 1]]
      test_model.visits.referers.today.should == [["firefox", 1]]
    end

    it "should have 0 visits yesterday" do
      test_model.visits("Mozilla Firefox").inc
      test_model.visits.browsers.yesterday.should == [["mozilla", 0]]
      test_model.visits.referers.yesterday.should == [["firefox", 0]]
    end

    it "should have 1 visits last 7 days" do
      test_model.visits("Mozilla Firefox").inc      
      test_model.visits.browsers.last_days(7).should == [["mozilla", [0, 0, 0, 0, 0, 0, 1]]]
      test_model.visits.referers.last_days(7).should == [["firefox", [0, 0, 0, 0, 0, 0, 1]]]
    end

    it "should work also for arbitrary days" do
      test_model.visits("Mozilla Firefox").inc      
      test_model.visits.browsers.last_days(15).should == [["mozilla", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]]]
      test_model.visits.referers.last_days(15).should == [["firefox", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]]]
    end

    it "should work adding 1 visit with different aggregation data" do
      test_model.visits("Mozilla Firefox").inc
      test_model.visits("Google Chrome").inc
      test_model.visits.browsers.today.should =~ [["mozilla", 1], ["google", 1]]
      test_model.visits.referers.today.should =~ [["firefox", 1], ["chrome", 1]]

      # Just for testing array manipulations
      test_model.visits.browsers.today.inject(0) {|total, c| total + c.last }.should == 2
    end

    it "should return only values when specifying the aggregation key" do
      test_model.visits("Mozilla Firefox").inc
      test_model.visits.browsers("mozilla").today.should == 1
    end

    it "should work also with set" do
      test_model.visits("Mozilla Firefox").inc
      test_model.visits("Google Chrome").set(5)
      test_model.visits.browsers.today.should =~ [["mozilla", 1], ["google", 5]]
      test_model.visits.referers.today.should =~ [["firefox", 1], ["chrome", 5]]
      test_model.visits.today.should == 5
    end

    it "let's check what happens when sorting the best browser..." do
      test_model.visits("Mozilla Firefox").inc
      test_model.visits("Google Chrome").set(6)
      test_model.visits.browsers.today.should =~ [["mozilla", 1], ["google", 6]]
      test_model.visits.browsers.today.max {|a,b| a.second <=> b.second }.should == ["google", 6]
    end

    it "should work without aggregation information" do
      test_model.visits("Mozilla Firefox").set(1)
      test_model.visits("Google Chrome").set(6)
      test_model.visits.inc


      test_model.visits.browsers.today.should =~ [["mozilla", 1], ["google", 6]]
      test_model.visits.referers.today.should =~ [["firefox", 1], ["chrome", 6]]

      # A more throughout test would check totals...
      visits_today = test_model.visits.today
      visits_today_with_browser = test_model.visits.browsers.today.inject(0) {|total, c| total + c.last }
      visits_today.should == visits_today_with_browser
    end
  end

  describe "When using reset method for aggregates" do
    let(:test_model) do
      TestModel.create(:name => "test")
    end

    before(:each) do
      test_model.visits("Mozilla Firefox").set(1, "2010-07-11")
      test_model.visits("Google Chrome").set(2, "2010-07-11")
      test_model.visits("Internet Explorer").set(3, "2010-07-11")

      test_model.visits("Mozilla Firefox").set(4, "2010-07-14")
      test_model.visits("Google Chrome").set(5, "2010-07-14")
      test_model.visits("Internet Explorer").set(6, "2010-07-14")

      test_model.uniques("Mozilla Firefox").set(1, "2010-07-11")
      test_model.uniques("Google Chrome").set(2, "2010-07-11")
      test_model.uniques("Internet Explorer").set(3, "2010-07-11")

      test_model.uniques("Mozilla Firefox").set(4, "2010-07-14")
      test_model.uniques("Google Chrome").set(5, "2010-07-14")
      test_model.uniques("Internet Explorer").set(6, "2010-07-14")
    end

    it "should have the correct values when using a value" do
      test_model.visits.reset(99, "2010-07-14")

      test_model.visits.on("2010-07-14").should == 99
      test_model.visits.browsers.all_values.should =~ [
        ["mozilla",  [1, 0, 0, 99]],
        ["google",   [2, 0, 0, 99]],
        ["internet", [3, 0, 0, 99]]
      ]
      test_model.visits.referers.all_values.should =~ [
        ["firefox",  [1, 0, 0, 99]],
        ["chrome",   [2, 0, 0, 99]],
        ["explorer", [3, 0, 0, 99]]
      ]
    end

    it "should delete the values when using nil" do
      test_model.visits.reset(nil, "2010-07-14")
      test_model.visits.on("2010-07-14").should == 0
      test_model.visits.browsers.all_values.should =~ [
        ["mozilla",  [1]],
        ["google",   [2]],
        ["internet", [3]]
      ]
      test_model.visits.referers.all_values.should =~ [
        ["firefox",  [1]],
        ["chrome",   [2]],
        ["explorer", [3]]
      ]
    end

    it "erase method sould also work" do
      test_model.visits.erase("2010-07-14")

      test_model.visits.on("2010-07-14").should == 0
      test_model.visits.browsers.all_values.should =~ [
        ["mozilla",  [1]],
        ["google",   [2]],
        ["internet", [3]]
      ]
    end

    it "should reset the correct tracking fields" do
      test_model.visits.reset(99, "2010-07-14")

      test_model.uniques.on("2010-07-14").should == 6
      test_model.uniques.browsers.all_values.should =~ [
        ["mozilla",  [1, 0, 0, 4]],
        ["google",   [2, 0, 0, 5]],
        ["internet", [3, 0, 0, 6]]
      ]
      test_model.uniques.referers.all_values.should =~ [
        ["firefox",  [1, 0, 0, 4]],
        ["chrome",   [2, 0, 0, 5]],
        ["explorer", [3, 0, 0, 6]]
      ]
    end

    it "should erase the correct tracking fields" do
      test_model.visits.erase("2010-07-14")

      test_model.uniques.on("2010-07-14").should == 6
      test_model.uniques.browsers.all_values.should =~ [
        ["mozilla",  [1, 0, 0, 4]],
        ["google",   [2, 0, 0, 5]],
        ["internet", [3, 0, 0, 6]]
      ]
      test_model.uniques.referers.all_values.should =~ [
        ["firefox",  [1, 0, 0, 4]],
        ["chrome",   [2, 0, 0, 5]],
        ["explorer", [3, 0, 0, 6]]
      ]
    end
  end

  describe "Testing all accessors" do
    let(:test_model) { TestModel.create(name: "test") }

    before do
      # For 'first' values
      test_model.visits("Mozilla Firefox").set(1, "2010-07-11")
      test_model.visits("Google Chrome").set(2, "2010-07-12")
      test_model.visits("Internet Explorer").set(3, "2010-07-13")

      # For 'last' values
      test_model.visits("Mozilla Firefox").set(4, "2010-07-14")
      test_model.visits("Google Chrome").set(5, "2010-07-15")
      test_model.visits("Internet Explorer").set(6, "2010-07-16")
    end

    it "should return the correct values for .all_values" do
      test_model.visits.all_values.should == [1, 2, 3, 4, 5, 6]
    end

    it "should return the all values for every aggregate" do
      test_model.visits.browsers.all_values.should =~ [
        ["mozilla",  [1, 0, 0, 4]],
        ["google",   [2, 0, 0, 5]],
        ["internet", [3, 0, 0, 6]]
      ]
    end

    it "should return the correct first_date for every aggregate" do
      test_model.visits.browsers.first_date.should =~ [
        ["mozilla",  Time.parse("2010-07-11")],
        ["google",   Time.parse("2010-07-12")],
        ["internet", Time.parse("2010-07-13")]
      ]
    end

    it "should return the correct last_date for every aggregate" do
      test_model.visits.browsers.last_date.should =~ [
        ["mozilla",  Time.parse("2010-07-14")],
        ["google",   Time.parse("2010-07-15")],
        ["internet", Time.parse("2010-07-16")]
      ]
    end

    it "should return the first value for aggregates" do
      test_model.visits.browsers.first_value.should =~ [
        ["mozilla",  1],
        ["google",   2],
        ["internet", 3]
      ]
    end

    it "should return the last value for aggregates" do
      test_model.visits.browsers.last_value.should =~ [
        ["mozilla",  4],
        ["google",   5],
        ["internet", 6]
      ]
    end
  end

  describe "When using models with same name on different namespaces" do
    let(:test_person1) do
      MyCompany::TestPerson.create(my_name: "twoixter") 
    end

    let(:test_person2) do
      YourCompany::TestPerson.create(your_name: "test")
    end

    before do      
      test_person1.logins("ASCII").set(1, "2012-07-07")
      test_person1.logins("EBCDIC").set(1, "2012-07-07")
      
      test_person2.logins("UTF8").set(1, "2012-07-07")
      test_person2.logins("LATIN1").set(1, "2012-07-07")
    end

    it "should be different objects" do
      test_person1.my_name.should_not == test_person2.your_name
    end

    it "should yield different aggregates" do
      test_person1.logins.initials.on("2012-07-07").should =~ [["A", 1], ["E", 1]]
      test_person2.logins.initials.on("2012-07-07").should =~ [["U", 1], ["L", 1]]
    end
  end
end

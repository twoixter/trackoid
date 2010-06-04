require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class TestModel
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field
  track :visits

  aggregate :browsers do
    "Mozilla"
  end
end

class SecondTestModel
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field
  track :visits

  aggregate :browsers do
    "Chrome"
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
    @mock.class.method_defined?(:browsers).should be_true
  end

  it "should have the aggregates klass in a instance var" do
    @mock.aggregate_klass == TestModelAggregates
  end

  it "should create an array in the class with all aggregate fields" do
    @mock.class.aggregate_fields.map(&:keys).flatten.should == [ :browsers ]
  end

  it "should create an array in the class with all aggregate fields even when monkey patching" do
    class TestModel
      aggregate :referers do
        "(none)"
      end
    end
    @mock.class.aggregate_fields.map(&:keys).flatten.should == [ :browsers, :referers ]
  end

  it "should indicate this is an aggregated traking object with aggregated?" do
    @mock.aggregated?.should be_true
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

end

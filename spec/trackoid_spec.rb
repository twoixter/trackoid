require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Test
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field
  track :visits
end

describe Mongoid::Tracking do

  before(:all) do
    @trackoid_version = File.read(File.expand_path("../VERSION", File.dirname(__FILE__)))
  end

  it "should expose the same version as the VERSION file" do
    Mongoid::Tracking::VERSION.should == @trackoid_version
  end
  
  it "should raise error when used in a class not of class Mongoid::Document" do
    lambda {
      class NotMongoidClass
        include Mongoid::Tracking
        track :something
      end
    }.should raise_error Mongoid::Errors::NotMongoid
  end

  it "should not raise error when used in a class of class Mongoid::Document" do
    lambda {
      class MongoidedDocument
        include Mongoid::Document
        include Mongoid::Tracking
        track :something
      end
    }.should_not raise_error
  end

  describe "when creating a new field with stats" do

    before(:all) do
      @mock = Test.new
    end

    it "should deny access to the underlying mongoid field" do
      lambda { @mock.visits_data }.should raise_error NoMethodError
      lambda { @mock.visits_data = {} }.should raise_error NoMethodError
    end

    it "should create a method for accesing the stats" do
      @mock.respond_to?(:visits).should be_true
    end

    it "should respond 'false' to field_changed? method" do
      # Ok, this test is not very relevant since it will return false even
      # if Trackid does not override it.
      @mock.visits_changed?.should be_false
    end

    it "should create a method for accesing the stats of the proper class" do
      @mock.visits.class.should == Mongoid::Tracking::Tracker
    end

    it "should create an array in the class with all tracking fields" do
      @mock.class.tracked_fields.should == [ :visits ]
    end

    it "should create an array in the class with all tracking fields even when monkey patching" do
      class Test
        track :something_else
      end
      @mock.class.tracked_fields.should == [ :visits, :something_else ]
    end

    it "should not update stats when new record" do
      lambda { @mock.visits.inc }.should raise_error Mongoid::Errors::ModelNotSaved
    end

    it "shold create an empty hash as the internal representation" do
      @mock.visits.send(:_original_hash).should == {}
    end

    it "should give 0 for today stats" do
      @mock.visits.today.should == 0
    end

    it "should give 0 for last 7 days stats" do
      @mock.visits.last_days.should == [0, 0, 0, 0, 0, 0, 0]
    end

    it "should give today stats for last 0 days stats" do
      @mock.visits.last_days(0).should == [@mock.visits.today]
    end

    it "should not be aggregated" do
      @mock.aggregated?.should be_false
    end

  end
  
  describe "when using a model in the database" do
    
    before(:all) do
      Test.delete_all
      Test.create(:name => "test")
      @object_id = Test.first.id
    end

    before do
      @mock = Test.find(@object_id)
    end

    it "should increment visits stats for today" do
      @mock.visits.inc
      @mock.visits.today.should == 1
    end

    it "should increment another visits stats for today for a total of 2" do
      @mock.visits.inc
      @mock.visits.today.should == 2
    end

    it "should also work for yesterday" do
      @mock.visits.inc(DateTime.now - 1)
      @mock.visits.yesterday.should == 1
    end

    it "should also work for yesterday if adding another visit (for a total of 2)" do
      @mock.visits.inc(DateTime.now - 1)
      @mock.visits.yesterday.should == 2
    end
    
    it "then, the visits of today + yesterday must be the same" do
      @mock.visits.last_days(2).should == [2, 2]
    end

    it "should have 4 visits for this test" do
      @mock.visits.last_days(2).sum.should == 4
    end

    it "should correctly handle the last 7 days" do
      @mock.visits.last_days.should == [0, 0, 0, 0, 0, 2, 2]
    end

  end

  context "testing accessor operations without reloading models" do

    before(:all) do
      Test.delete_all
      Test.create(:name => "test")
      @object_id = Test.first.id
    end

    before do
      @mock = Test.find(@object_id)
    end

    it "'set' operator must work" do
      @mock.visits.set(5)
      @mock.visits.today.should == 5
      Test.find(@object_id).visits.today.should == 5
    end

    it "'set' operator must work on arbitrary days" do
      @mock.visits.set(5, Date.parse("2010-05-01"))
      @mock.visits.on(Date.parse("2010-05-01")).should == 5
      Test.find(@object_id).visits.on(Date.parse("2010-05-01")).should == 5
    end

    it "'add' operator must work" do
      @mock.visits.add(5)
      @mock.visits.today.should == 10   # Remember 5 set on previous test
      Test.find(@object_id).visits.today.should == 10
    end

    it "'add' operator must work on arbitrary days" do
      @mock.visits.add(5, Date.parse("2010-05-01"))
      @mock.visits.on(Date.parse("2010-05-01")).should == 10
      Test.find(@object_id).visits.on(Date.parse("2010-05-01")).should == 10
    end

    it "on() accessor must work on dates as String" do
      # We have data for today as previous tests populated the visits field
      @mock.visits.on("2010-05-01").should == 10
    end

    it "on() accessor must work on dates as Date ancestors" do
      # We have data for today as previous tests populated the visits field
      @mock.visits.on(Date.parse("2010-05-01")).should == 10
    end

    it "on() accessor must work on dates as Ranges" do
      # We have data for today as previous tests populated the visits field
      @mock.visits.on(Date.parse("2010-04-30")..Date.parse("2010-05-02")).should == [0, 10, 0]
    end


  end



  context "regression test for github issues" do
    
    it "should not raise undefined method [] for nil:NilClass for objects already saved" do
      class TestModel
        include Mongoid::Document
        include Mongoid::Tracking
        field :name
      end
      TestModel.delete_all
      TestModel.create(:name => "dummy")

      class TestModel
        track :something
      end
      tm = TestModel.first
      tm.something.today.should == 0
      tm.something.inc
      tm.something.today.should == 1
    end

  end

end

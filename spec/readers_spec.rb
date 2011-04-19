require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Test
  include Mongoid::Document
  include Mongoid::Tracking

  field :name   # Dummy field
  track :visits
end

describe "Testing Readers with a model" do
  before do
    Test.delete_all
    Test.create(:name => "test")
    @object_id = Test.first.id
    @mock = Test.find(@object_id)
  end

  it "should return the correct values for a range using 'on'" do
    @mock.visits.set(1, "2010-07-11")
    @mock.visits.set(2, "2010-07-12")
    @mock.visits.set(3, "2010-07-13")

    range = Date.parse("2010-07-11")..Date.parse("2010-07-13")
    @mock.visits.on(range).should == [1, 2, 3]
  end

  it "should return the correct values for .all_values" do
    @mock.visits.set(1, "2010-07-11")
    @mock.visits.set(2, "2010-07-12")
    @mock.visits.set(3, "2010-07-13")
    
    @mock.visits.all_values.should == [1, 2, 3]
  end

  it "should return the correct values for .all_values (Take II)" do
    @mock.visits.set(5, "2010-07-01")
    @mock.visits.set(10, "2010-07-30")
  
    @mock.visits.all_values.should == [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10]
    @mock.visits.last_value.should == 10
    @mock.visits.first_value.should == 5
  end
end


describe "Testing Readers with an empty model" do
  before do
    Test.delete_all
    Test.create(:name => "test")
    @object_id = Test.first.id
    @mock = Test.first
  end

  it "should return nil for .first_date" do
    @mock.visits.first_date.should be_nil
  end

  it "should return nil for .last_date" do
    @mock.visits.last_date.should be_nil
  end

  it "should return nil for .first_value" do
    @mock.visits.first_value.should be_nil
  end

  it "should return nil for .last_value" do
    @mock.visits.last_value.should be_nil
  end

  it "should return nil for .all_values" do
    @mock.visits.all_values.should be_nil
  end
end

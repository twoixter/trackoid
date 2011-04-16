require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongoid::Tracking::ReaderExtender do
  it "should behave like a number" do
    num = Mongoid::Tracking::ReaderExtender.new(5, [])
    num.should == 5
    num.should < 10
    (num * 10).should == 50
  end

  it "should behave like a float" do
    num = Mongoid::Tracking::ReaderExtender.new(5, [])
    num.should == 5.0
    num.should < 10.0
    (num * 10.0).should == 50.0
  end

  it "to_f should return a Float (for ActionView::Template compat.)" do
    num = Mongoid::Tracking::ReaderExtender.new(5, [])
    num.to_f.should == 5.0
    num.to_f.should be_kind_of(Float)
  end

  it "as_json should return a 'total' and a 'hours' member" do
    json = Mongoid::Tracking::ReaderExtender.new(5, []).as_json
    json.should have_key("total")
    json.should have_key("hours")
  end

  it "should be able to add additional data to it" do
    num = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    num.hourly.should == [1, 2, 3, 4]
  end

  it "should be able to sum two ReadersExtenders" do
    a = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    b = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    c = a + b
    c.should == 10
    c.hourly.should == [2, 4, 6, 8]
  end

  it "should be able to sum more than two ReadersExtenders" do
    a = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    b = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    c = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    d = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    e = Mongoid::Tracking::ReaderExtender.new(5, [1, 2, 3, 4])
    f = a + b + c + d + e
    f.should == 25
    f.hourly.should == [5, 10, 15, 20]
  end
end

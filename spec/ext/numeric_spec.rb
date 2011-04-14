require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Numeric do
  it "should behave like a number, well... because it's a number. :-)" do
    num = 5
    num.should == 5
  end

  it "should be able to add additional data to it" do
    num = 5.set_hours([1, 2, 3, 4])
    num.hourly.should == [1, 2, 3, 4]
  end
end

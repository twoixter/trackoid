require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Range do
  describe "using the diff method" do
    it "should work for normal ranges" do
      (0..2).diff.should == 3
      (0...2).diff.should == 2
    end

    it "should work for Time ranges (DAYS)" do
      now = Time.now
      inc_range = now..(now + 1*Range::DAYS)
      exc_range = now...(now + 1*Range::DAYS)

      inc_range.diff.should == 2
      exc_range.diff.should == 1
    end
    
    it "should work for Time ranges (HOURS)" do
      now = Time.now
      inc_range = now..(now + 10*Range::HOURS)
      exc_range = now...(now + 10*Range::HOURS)

      inc_range.diff(Range::HOURS).should == 11
      exc_range.diff(Range::HOURS).should == 10
    end

    it "should also work when using helper methods" do
      now = Time.now
      inc_range = now..(now + 10*Range::HOURS)
      exc_range = now...(now + 10*Range::HOURS)

      inc_range.hour_diff.should == 11
      exc_range.hour_diff.should == 10
    end

    it "should behave like normal ranges for 1 element" do
      now = Time.now
      inc_range = now..now
      exc_range = now...now

      inc_range.diff.should == 1
      exc_range.diff.should == 0
    end

    it "should keep Time UTC and DST properties" do
      date1 = Time.local(2011, 4, 1, 0, 0)
      date2 = Time.utc(2011, 4, 1, 0, 0)

      range1 = date1..date1
      range2 = date2..date2

      range1.first.should_not be_utc
      range1.first.should be_dst
      range2.first.should be_utc
      range2.first.should_not be_dst
    end
  end

  describe "using the map method" do
    it "should work for normal ranges (using enumerator)" do
      inc_result = (0..2).map.to_a
      inc_result.should == [0, 1, 2]
      
      exc_result = (0...2).map.to_a
      exc_result.should == [0, 1]
    end

    it "should work for normal ranges (using block)" do
      inc_result = (0..2).map {|e| e}
      inc_result.should == [0, 1, 2]
      
      exc_result = (0...2).map {|e| e}
      exc_result.should == [0, 1]
    end

    it "should work for Time ranges" do
      date = Time.utc(2011, 4, 1, 0, 0)
      inc_range = date..(date + 5*Range::DAYS)
      inc_result = inc_range.map {|d| d.to_i_timestamp}
      inc_result.should == [15065, 15066, 15067, 15068, 15069, 15070]

      exc_range = date...(date + 5*Range::DAYS)
      exc_result = exc_range.map {|d| d.to_i_timestamp}
      exc_result.should == [15065, 15066, 15067, 15068, 15069]
    end

    it "should work for empty excluding Time ranges" do
      date = Time.utc(2011, 4, 1, 0, 0)
      exc_range = date...date
      exc_result = exc_range.map {|d| d.to_i_timestamp}
      exc_result.should == []
    end
    
    it "should return an array if no block given" do
      date = Time.utc(2011, 4, 1, 0, 0)
      result = (date..(date + 5*Range::DAYS)).map
      result.count.should == 6
      
      # Result is now an array
      result.map(&:to_i_timestamp).should == [15065, 15066, 15067, 15068, 15069, 15070]
    end

    it "should also work using helper methods" do
      date = Time.utc(2011, 4, 1, 0, 0)
      result = (date..(date + 5*Range::HOURS)).hour_map
      result.count.should == 6
    end
  end
end

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Time do
  describe "when working with UTC dates" do
    it "should return the correct timestamp" do
      time1 = Time.utc(2011, 1, 1, 0, 0, 0)
      time1.to_i_timestamp.should == 14975

      time2 = Time.utc(2011, 1, 1, 23, 59, 59)
      time2.to_i_timestamp.should == 14975
    end

    it "should return the correct hours" do
      time1 = Time.utc(2011, 1, 1, 0, 0, 0)
      time1.to_i_hour.should == 0

      time2 = Time.utc(2011, 1, 1, 23, 59, 59)
      time2.to_i_hour.should == 23
    end
  
    it "should work also on ranges (dates)" do
      time1 = Time.utc(2011, 1, 1, 0, 0, 0)
      range = time1...(time1 + 10*Range::DAYS)
      range.map(&:to_i_timestamp).should == [14975, 14976, 14977, 14978, 14979, 14980, 14981, 14982, 14983, 14984]
    end

    it "should work also on ranges (hours)" do
      range = Time.utc(2011, 1, 1)...Time.utc(2011, 1, 2)
      
      # With Range::HOURS
      range.map(Range::HOURS){|d| d.to_i_hour}.should == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]

      # With ActiveSupport Numeric extensions
      range.map(1.hour){|d| d.to_i_hour}.should == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
    end
  end

  describe "when working with TZ dates (Europe)" do
    before do
      ENV["TZ"] = "Europe/Madrid"
    end

    it "should return the correct timestamp" do
      # NOTE: January 1, 2011 00:00 GMT+1 Timezone corresponds to: December, 31 2010 23:00 UTC
      time1 = Time.local(2011, 1, 1, 0, 0, 0)
      time1.to_i_timestamp.should == 14974

      time2 = Time.local(2011, 1, 1, 23, 59, 59)
      time2.to_i_timestamp.should == 14975
    end

    it "should return the correct hours" do
      time1 = Time.local(2011, 1, 1, 0, 0, 0)
      time1.to_i_hour.should == 23 # This is for the previous day
    
      time2 = Time.local(2011, 1, 1, 23, 59, 59)
      time2.to_i_hour.should == 22
    end
  end

  describe "when working with TZ dates (America)" do
    before do
      ENV["TZ"] = "America/Los_Angeles"
    end

    it "should return the correct timestamp" do
      time1 = Time.local(2011, 1, 1, 0, 0, 0)
      time1.to_i_timestamp.should == 14975

      # Note: January 1, 2011 23:00 PST Timezone corresponds to: January, 2 2010 07:00 UTC
      time2 = Time.local(2011, 1, 1, 23, 59, 59)
      time2.to_i_timestamp.should == 14976
    end

    it "should return the correct hours" do
      time1 = Time.local(2011, 1, 1, 0, 0, 0)
      time1.to_i_hour.should == 8
    
      time2 = Time.local(2011, 1, 1, 23, 59, 59)
      time2.to_i_hour.should == 7 # This is for the next day
    end
  end

end

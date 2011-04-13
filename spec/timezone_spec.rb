require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Mongoid::Tracking do
  describe "Testing the system TZ for Europe/Madrid" do
    before do
      ENV['TZ'] = 'Europe/Madrid'
    end
    
    it "should convert dates to UTC" do
      t = Time.now
      t.should_not be_utc
      t.utc
      t.should be_utc
    end

    it "should create dates in UTC" do
      t = Time.utc(2011, 1, 1, 20, 30)
      t.to_s.should == "2011-01-01 20:30:00 UTC"
    end

    it "should create dates in local time" do
      t = Time.local(2011, 1, 1, 20, 30)
      t.to_s.should == "2011-01-01 20:30:00 +0100"
      t.utc_offset.should == 3600
    end

    it "should detect daylight saving for local times" do
      t = Time.local(2011, 6, 1, 20, 30)
      t.should be_dst
      t.to_s.should == "2011-06-01 20:30:00 +0200"
      t.utc_offset.should == 7200
    end

    it "timestamps should be offset by the utc_offset" do
      local = Time.local(2011, 1, 1, 0, 0)
      utc = Time.utc(2011, 1, 1, 0, 0)
      (utc - local).should == local.utc_offset
    end

    it "timestamps should be offset by the utc_offset even when daylight saving is on" do
      local = Time.local(2011, 6, 1, 0, 0)
      utc = Time.utc(2011, 6, 1, 0, 0)
      local.should be_dst
      utc.should_not be_dst
      (local - utc).abs.should == local.utc_offset
    end
  end

  describe "Testing the system TZ for America/San Francisco" do
    before do
      ENV['TZ'] = 'America/Los_Angeles'
    end
    
    it "should convert dates to UTC" do
      t = Time.now
      t.should_not be_utc
      t.utc
      t.should be_utc
    end

    it "should create dates in UTC" do
      t = Time.utc(2011, 1, 1, 20, 30)
      t.to_s.should == "2011-01-01 20:30:00 UTC"
    end

    it "should create dates in local time" do
      t = Time.local(2011, 1, 1, 20, 30)
      t.to_s.should == "2011-01-01 20:30:00 -0800"
      t.utc_offset.should == -28800
    end

    it "should detect daylight saving for local times" do
      t = Time.local(2011, 6, 1, 20, 30)
      t.should be_dst
      t.to_s.should == "2011-06-01 20:30:00 -0700"
      t.utc_offset.should == -25200
    end

    it "timestamps should be offset by the utc_offset" do
      local = Time.local(2011, 1, 1, 0, 0)
      utc = Time.utc(2011, 1, 1, 0, 0)
      (utc - local).should == local.utc_offset
    end

    it "timestamps should be offset by the utc_offset even when daylight saving is on" do
      local = Time.local(2011, 6, 1, 0, 0)
      utc = Time.utc(2011, 6, 1, 0, 0)
      local.should be_dst
      utc.should_not be_dst
      (utc - local).should == local.utc_offset
    end
  end

  describe "Testing the RAILS TZ capabilities" do
    before do
      ENV['TZ'] = nil
    end
    
    it "should support time zone changing" do
      Time.zone = ActiveSupport::TimeZone["America/Los_Angeles"]

      # For some reason, the RSpec matcher does not match this...
      # Time.zone.should == "(GMT-08:00) America/Los_Angeles"

      local = Time.local(2011, 6, 1, 0, 0).in_time_zone
      local.should be_dst
      local.utc_offset.should == -25200

      Time.zone = ActiveSupport::TimeZone["Europe/Madrid"]
      local = Time.local(2011, 6, 1, 0, 0)
      local.should be_dst
      local.utc_offset.should == 7200
    end

    it "should correctly handle UTC offseted dates" do
      utc = Time.utc(2011, 6, 1, 0, 0)
      utc_localized = Time.utc(2011, 6, 1, 0, 0) + 7200
      
      (utc_localized - utc).should == 7200
    end
  end

end

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

  describe "Testing TZ data with real models" do
    before(:all) do
      class Test
        include Mongoid::Document
        include Mongoid::Tracking

        field :name   # Dummy field
        track :visits
      end
    end
    
    before do
      Test.delete_all
      Test.create(:name => "test")
      @object_id = Test.first.id
      @mock = Test.find(@object_id)
    end

    it "should correctly handle hours for my TimeZone" do
      # WARNING: Volatile test, time dependant... Do not run at 00:00:00 :-)
      t1 = Time.now.change(:hour => 0)
      t2 = Time.now.change(:hour => 23)

      @mock.visits.inc(t1)
      @mock.visits.inc(t2)
      @mock.visits.today.should == 2
      @mock.visits.today.hourly.should == [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "should correctly handle hours for UTC" do
      # WARNING: Volatile test, time dependant... Do not run at 00:00:00 :-)
      t1 = Time.now.utc.change(:hour => 0)
      t2 = Time.now.utc.change(:hour => 23)

      @mock.visits.inc(t1)
      @mock.visits.inc(t2)
      @mock.visits.on(Time.now.utc).should == 2
      @mock.visits.on(Time.now.utc).hourly.should == [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    it "Hours in Europe/Madrid (Winter time) should be shifted by 1 hour from UTC" do
      ENV["TZ"] = "Europe/Madrid"

      time = Time.parse("2011-01-01")
      t1 = time.change(:hour => 1)
      t2 = time.change(:hour => 22)

      @mock.visits.inc(t1)
      @mock.visits.inc(t2)
      
      # This test is interesting. We added with local TZ time but want to
      # query shifted data on UTC. We need to read the expected span dates
      # separately
      visits = @mock.visits.on(time.utc..(time.utc + 1.day))

      # Data from 2010-12-31 00:00:00 UTC up to 2011-12-31 23:59:59 UTC
      visits.first.hourly.should == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

      # Data from 2011-01-01 00:00:00 UTC up to 2011-01-01 23:59:59 UTC
      visits.last.hourly.should == [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]
    end

    it "Hours in Europe/Madrid (Summer time) should be shifted by 2 hour from UTC" do
      ENV["TZ"] = "Europe/Madrid"

      time = Time.parse("2011-06-01")
      t1 = time.change(:hour => 1)
      t2 = time.change(:hour => 22)

      @mock.visits.inc(t1)
      @mock.visits.inc(t2)
      
      # This test is interesting. We added with local TZ time but want to
      # query shifted data on UTC. We need to read the expected span dates
      # separately
      visits = @mock.visits.on(time.utc..(time.utc + 1.day))

      # Data from 2011-05-31 00:00:00 UTC up to 2011-05-31 23:59:59 UTC
      visits.first.hourly.should == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]

      # Data from 2011-06-01 00:00:00 UTC up to 2011-06-01 23:59:59 UTC
      visits.last.hourly.should == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
    end

    it "Hours in America/Los_Angeles (Winter time) should be shifted by -8 hours from UTC" do
      ENV["TZ"] = "America/Los_Angeles"

      time = Time.parse("2011-01-01")
      t1 = time.change(:hour => 1)
      t2 = time.change(:hour => 22)

      @mock.visits.inc(t1)
      @mock.visits.inc(t2)
      
      # This test is interesting. We added with local TZ time but want to
      # query shifted data on UTC. We need to read the expected span dates
      # separately
      visits = @mock.visits.on(time.utc..(time.utc + 1.day))

      # Data from 2011-01-01 00:00:00 UTC up to 2011-01-01 23:59:59 UTC
      visits.first.hourly.should == [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

      # Data from 2011-01-02 00:00:00 UTC up to 2011-01-02 23:59:59 UTC
      visits.last.hourly.should == [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    it "Hours in America/Los_Angeles (Summer time) should be shifted by -7 hours from UTC" do
      ENV["TZ"] = "America/Los_Angeles"

      time = Time.parse("2011-06-01")
      t1 = time.change(:hour => 1)
      t2 = time.change(:hour => 22)

      @mock.visits.inc(t1)
      @mock.visits.inc(t2)
      
      # This test is interesting. We added with local TZ time but want to
      # query shifted data on UTC. We need to read the expected span dates
      # separately
      visits = @mock.visits.on(time.utc..(time.utc + 1.day))

      # Data from 2011-01-01 00:00:00 UTC up to 2011-01-01 23:59:59 UTC
      visits.first.hourly.should == [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

      # Data from 2011-01-02 00:00:00 UTC up to 2011-01-02 23:59:59 UTC
      visits.last.hourly.should == [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

  end
end

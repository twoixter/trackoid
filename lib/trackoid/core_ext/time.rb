class Time
  # Functions to construct the MongoDB field key for trackers
  #
  # to_i_timestamp returns the computed UTC timestamp regardless of the
  # timezone.
  #
  # Examples:
  #    2011-01-01 00:00:00 UTC  ===> 14975
  #    2011-01-01 23:59:59 UTC  ===> 14975
  #    2011-01-02 00:00:00 UTC  ===> 14976
  # 
  # to_i_hour returns the hour for the date, again regardless of TZ
  #
  #    2011-01-01 00:00:00 UTC  ===> 0
  #    2011-01-01 23:59:59 UTC  ===> 23
  #
  ONEDAY = 60 * 60 * 24

  def to_i_timestamp
    self.dup.utc.to_i / ONEDAY
  end

  def to_i_hour
    self.dup.utc.hour
  end

  # Returns an integer to use as MongoDB key
  def to_key
    "#{to_i_timestamp}.#{to_i_hour}"
  end

  # Returns a range to be enumerated using hours for the whole day
  def whole_day
    # We could have used 'beginning_of_day' from ActiveSupport, but don't
    # want to introduce a dependency (I've tried to avoid ActiveSupport
    # although you will be using it since it's introduced by Mongoid)
    midnight = Time.send(utc? ? :utc : :local, year, month, day)
    midnight...(midnight + ::Range::DAYS)
  end
end
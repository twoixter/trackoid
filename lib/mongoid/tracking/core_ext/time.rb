# encoding: utf-8
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
  ONEHOUR = 60 * 60
  ONEDAY = 24 * ONEHOUR

  def to_i_timestamp
    self.dup.utc.to_i / ONEDAY
  end

  def to_key_timestamp
    to_i_timestamp.to_s
  end

  def to_i_hour
    self.dup.utc.hour
  end

  def to_key_hour
    to_i_hour.to_s
  end

  # Returns an integer to use as MongoDB key
  def to_key
    "#{to_i_timestamp}.#{to_i_hour}"
  end

  def self.from_key(ts, h)
    Time.at(ts.to_i * ONEDAY + h.to_i * ONEHOUR)
  end

  # Returns a range to be enumerated using hours for the whole day
  def whole_day
    midnight = utc? ? Time.utc(year, month, day) : Time.new(year, month, day, 0, 0, 0, utc_offset)
    midnight...(midnight + ::Range::DAYS)
  end
end
